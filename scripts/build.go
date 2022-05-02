package main

import (
	"os"
	"path/filepath"
)

type Package struct {
	Manifest  interface{}
	Templates []string
	Variables map[string][]string
}

func main() {
	filepath.Walk(os.Args[1], func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}

		f, err := os.Open(path)
	})
}
