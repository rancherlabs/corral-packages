package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/sirupsen/logrus"

	corralpkg "github.com/rancherlabs/corral/pkg/package"
	"gopkg.in/yaml.v3"
)

type Manifest struct {
	Name        string
	Description string
}

type OrderedMap struct {
	Values   map[string][]string
	Ordering []string
}

func (o *OrderedMap) UnmarshalYAML(value *yaml.Node) error {
	if value.Kind != yaml.MappingNode {
		return fmt.Errorf("cannot unmarshal orderedmap for %v", value.Kind)
	}
	o.Values = map[string][]string{}
	o.Ordering = []string{}
	prev := ""
	for _, v := range value.Content {
		switch v.Kind {
		case yaml.ScalarNode:
			o.Ordering = append(o.Ordering, v.Value)
			prev = v.Value
		case yaml.SequenceNode:
			if prev == "" {
				return fmt.Errorf("variables must be a map")
			}
			tmp := make([]string, len(v.Content))
			err := v.Decode(&tmp)
			if err != nil {
				return err
			}
			o.Values[prev] = tmp
		}
	}

	return nil
}

type Package struct {
	Manifest  Manifest
	Templates []string
	Variables OrderedMap
}

func main() {
	logrus.Info("Removing existing packages")
	err := os.RemoveAll("dist")
	if err != nil {
		logrus.Fatal(err)
	}

	logrus.Info("Creating dist folder")
	err = os.MkdirAll("dist", 0775)
	if err != nil {
		logrus.Fatal(err)
	}

	filepath.Walk(os.Args[1], func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		logrus.Infof("processing %s", path)

		body, err := os.ReadFile(path)
		if err != nil {
			logrus.Fatal(err)
		}

		p := Package{}
		if err = yaml.Unmarshal(body, &p); err != nil {
			logrus.Fatal(err)
		}

		packages := make([]corralpkg.Package, len(p.Templates))
		for i, t := range p.Templates {
			logrus.Infof("Loading template for %s", t)
			merge, err := corralpkg.LoadPackage(filepath.Join("templates", t))
			if err != nil {
				logrus.Fatal(err)
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

		tmplLocation, err := os.MkdirTemp(os.TempDir(), "corral-packages")
		if err != nil {
			logrus.Fatal(err)
		}
		defer os.RemoveAll(tmplLocation)

		tmpl, err := corralpkg.MergePackages(tmplLocation, packages)
		if err != nil {
			logrus.Fatal(err)
		}

		for i := range packages {
			if i > 0 {
				tmpl.Description += "\n"
			}

			if packages[i].Description != "" {
				tmpl.Description += packages[i].Description
			}
		}
		tmpl.Name = strings.Join(p.Templates, "-")

		buf, _ := yaml.Marshal(tmpl)

		err = os.WriteFile(filepath.Join(tmplLocation, "manifest.yaml"), buf, 0664)
		if err != nil {
			logrus.Fatal("failed to write manifest: ", err)
		}

		logrus.Info("Generating variable manifests")

		tmplPkg, err := corralpkg.LoadPackage(tmplLocation)
		if err != nil {
			logrus.Fatal(err)
		}

		varPkgs := map[string][]corralpkg.Package{}

		for varName, vars := range p.Variables.Values {
			logrus.Infof("Generating variable manifests for %s", varName)

			varLocation, err := os.MkdirTemp(os.TempDir(), "corral-packages")
			if err != nil {
				logrus.Fatal(err)
			}
			defer os.RemoveAll(varLocation)

			err = os.MkdirAll(filepath.Join(varLocation, varName), 0775)
			if err != nil {
				logrus.Fatal(err)
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

				logrus.Debugf("Generating variable manifests for %s to pin at %s", varName, v)
				varManifest := VariableManifest{
					RootPath:    filepath.Join(varLocation, varName, name),
					Name:        name,
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
					logrus.Fatal(err)
				}

				varRoot := filepath.Join(varLocation, varName, name)

				err = os.MkdirAll(varRoot, 0775)
				if err != nil {
					logrus.Fatal(err)
				}

				err = os.WriteFile(filepath.Join(varRoot, "manifest.yaml"), buf, 0664)
				if err != nil {
					logrus.Fatal(err)
				}

				varPkg, err := corralpkg.LoadPackage(varRoot)
				if err != nil {
					logrus.Fatal(err)
				}
				if _, ok := varPkgs[varName]; !ok {
					varPkgs[varName] = []corralpkg.Package{}
				}
				varPkgs[varName] = append(varPkgs[varName], varPkg)
			}
		}

		varMatrix := make([][]corralpkg.Package, len(varPkgs))
		for i, v := range p.Variables.Ordering {
			varMatrix[i] = varPkgs[v]
		}

		product := cartesianProductN[corralpkg.Package](varMatrix)
		for _, vars := range product {
			names := []string{tmpl.Name}
			pkgs := []corralpkg.Package{tmplPkg}
			for _, v := range vars {
				names = append(names, v.Name)
				pkgs = append(pkgs, v)
			}

			name := strings.Join(names, "-")

			distTmpl, err := corralpkg.MergePackages(filepath.Join("dist", name), append([]corralpkg.Package{tmplPkg}, vars...))
			if err != nil {
				logrus.Fatal(err)
			}
			distTmpl.Description = tmplPkg.Description

			for i := range vars {
				if len(distTmpl.Description) > 0 {
					distTmpl.Description += "\n\n"
				}

				distTmpl.Description += vars[i].Description
			}
			distTmpl.Name = name

			buf, err = yaml.Marshal(distTmpl)
			if err != nil {
				logrus.Fatal(err)
			}

			err = os.WriteFile(filepath.Join("dist", name, "manifest.yaml"), buf, 0664)
			if err != nil {
				logrus.Fatal("failed to write manifest: ", err)
			}
		}

		return nil
	})
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
