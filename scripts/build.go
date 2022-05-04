package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	log "github.com/sirupsen/logrus"

	corralpkg "github.com/rancherlabs/corral/pkg/package"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"
)

type Manifest struct {
	Name        string
	Description string
}

type Package struct {
	Manifest  Manifest
	Templates []string
	Variables map[string][]string
}

func main() {
	log.Info("Removing existing packages")
	err := os.RemoveAll("dist")
	if err != nil {
		log.Fatal(err)
	}

	log.Info("Creating dist folder")
	err = os.MkdirAll("dist", 0775)
	if err != nil {
		log.Fatal(err)
	}


	filepath.Walk(os.Args[1], func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		log.Infof("Processing %s", path)

		body, err := os.ReadFile(path)
		if err != nil {
			log.Fatal(err)
		}

		var p Package
		if err = yaml.Unmarshal(body, &p); err != nil {
			log.Fatal(err)
		}

		log.Info("Loading templates")

		packages := make([]corralpkg.Package, len(p.Templates))
		for i, t := range p.Templates {
			log.Debugf("Loading template for %s", t)
			merge, err := corralpkg.LoadPackage(filepath.Join("templates", t))
			if err != nil {
				log.Fatal(err)
			}
			packages[i] = merge
		}

		// For nested packages, just use top level name
		for i, t := range p.Templates {
			idx := strings.IndexRune(t, '/')
			if idx != -1 {
				p.Templates[i] = t[0:idx]
			}
		}

		tmplName := strings.Join(p.Templates, "-")

		log.Infof("Generating staging template %s", tmplName)

		tmpl, err := corralpkg.MergePackages(filepath.Join("staging", tmplName), packages)
		if err != nil {
			log.Fatal(err)
		}

		// todo this logic is duplicated by corral/cmd/package.Template, fix
		for i := range packages {
			if i > 0 {
				tmpl.Description += "\n"
			}

			if packages[i].Description != "" {
				tmpl.Description += packages[i].Description
			}
		}
		tmpl.Name = filepath.Base(tmplName)

		buf, _ := yaml.Marshal(tmpl)

		err = os.WriteFile(filepath.Join("staging", tmplName, "manifest.yaml"), buf, 0664)
		if err != nil {
			log.Fatal("failed to write manifest: ", err)
		}

		log.Info("Generating variable manifests")

		err = os.MkdirAll("variables", 0775)
		if err != nil {
			log.Fatal(err)
		}

		tmplPkg, err := corralpkg.LoadPackage(filepath.Join("staging", tmplName))
		if err != nil {
			log.Fatal(err)
		}

		varPkgs := map[string][]corralpkg.Package{}

		for varName, vars := range p.Variables {
			log.Infof("Generating variable manifests for %s", varName)
			err = os.MkdirAll(filepath.Join("variables", varName), 0775)
			if err != nil {
				log.Fatal(err)
			}

			type VariableManifest struct {
				RootPath    string
				Name        string
				Description string
				Variables   map[string]interface{}
			}

			for _, v := range vars {
				// since the name will be part of the image name, ensure it is compatible
				r := regexp.MustCompile("[^A-Za-z-_0-9.]")
				name := r.ReplaceAllString(v, "-")

				log.Debugf("Generating variable manifests for %s to pin at %s", varName, v)
				varManifest := VariableManifest{
					RootPath: filepath.Join("variables", varName, name),
					Name:     name,
					Description: fmt.Sprintf("%s is pinned to %s.", varName, v),
					Variables: map[string]interface{}{
						varName: struct {
							ReadOnly bool `yaml:"readOnly"`
							Default  interface{}
						}{
							ReadOnly: true,
							Default:  v,
						},
					},
				}
				buf, err = yaml.Marshal(varManifest)
				if err != nil {
					log.Fatal(err)
				}

				varRoot := filepath.Join("variables", varName, name)

				err = os.MkdirAll(varRoot, 0775)
				if err != nil {
					log.Fatal(err)
				}

				// todo this logic is duplicated by corral/cmd/package.Template, fix
				err = os.WriteFile(filepath.Join(varRoot, "manifest.yaml"), buf, 0664)
				if err != nil {
					log.Fatal(err)
				}

				varPkg, err := corralpkg.LoadPackage(varRoot)
				if err != nil {
					log.Fatal(err)
				}
				if _, ok := varPkgs[varName]; !ok {
					varPkgs[varName] = []corralpkg.Package{}
				}
				varPkgs[varName] = append(varPkgs[varName], varPkg)
			}
		}

		// This order isn't strictly perfect according to the yaml definition due to map iteration order, so this is
		// currently a best effort approximation assuming the variables should be ordered alphabetically.
		varMatrix := make([][]corralpkg.Package, len(varPkgs))
		keys := make([]string, len(varPkgs))
		{
			i := 0
			for k := range varPkgs {
				keys[i] = k
				i++
			}
		}
		sort.Strings(keys)
		for i, v := range keys {
			varMatrix[i] = varPkgs[v]
		}

		product := cartesianProductN[corralpkg.Package](varMatrix)
		for _, vars := range product {
			names := []string{tmplName}
			pkgs := []corralpkg.Package{tmplPkg}
			for _, v := range vars {
				names = append(names, v.Name)
				pkgs = append(pkgs, v)
			}

			name := strings.Join(names, "-")

			tmpl, err = corralpkg.MergePackages(filepath.Join("dist", name), append([]corralpkg.Package{tmplPkg}, vars...))
			if err != nil {
				log.Fatal(err)
			}
			tmpl.Description = tmplPkg.Description

			// todo this logic is duplicated by corral/cmd/package.Template, fix
			for i := range vars {
				if len(tmpl.Description) > 0 {
					tmpl.Description += "\n\n"
				}

				tmpl.Description += vars[i].Description
			}
			tmpl.Name = name

			buf, err = yaml.Marshal(tmpl)
			if err != nil {
				log.Fatal(err)
			}

			err = os.WriteFile(filepath.Join("dist", name, "manifest.yaml"), buf, 0664)
			if err != nil {
				logrus.Fatal("failed to write manifest: ", err)
			}
		}

		return nil
	})

	err = os.RemoveAll("staging")
	if err != nil {
		log.Warnf("Could not remove staging directory")
	}

	err = os.RemoveAll("variables")
	if err != nil {
		log.Warnf("Could not remove variables directory")
	}
}

// create a n-ary cartesian product where the dimension is equal to len(t)
func cartesianProductN[T any](t [][]T) [][]T {
	if len(t) == 0 {
		return [][]T{}
	}
	return cartesianProductNHelper[T]([]T{}, t)
}

func cartesianProductNHelper[T any](t1 []T, t [][]T) [][]T {
	ret := [][]T{}
	if len(t) == 1 {
		for _, v := range t[0] {
			ret = append(ret, append(t1, v))
		}
		return ret
	}
	for _, v := range t[0] {
		tmp := cartesianProductNHelper(append(t1, v), t[1:])
		ret = append(ret, tmp...)
	}

	return ret
}
