package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"gopkg.in/yaml.v3"
)

func main() {
	os.Exit(int(realMain()))
}

type exitCode int

func realMain() exitCode {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: gh-from-file <file> <gh commands>")
		return 1
	}

	file := os.Args[1]
	ghCommands := os.Args[2:]

	// Load the file into a yaml map
	data, err := os.ReadFile(file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		return 1
	}

	var yamlData map[string]any
	if err := yaml.Unmarshal(data, &yamlData); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing YAML: %v\n", err)
		return 1
	}

	// Validate key values are only one level deep, otherwise it's an error
	for key, value := range yamlData {
		if _, ok := value.(map[string]any); ok {
			fmt.Fprintf(os.Stderr, "Error: key '%s' has a value that is a map, which is not allowed\n", key)
			return 1
		}
	}

	// For each key in the yaml file, add a flag to the slice of args, where the value of the flag
	// is the values of the key in the yaml file. Slices should be joined with commas.
	var args []string
	for key, value := range yamlData {
		// If the key is "positional", take the array of values and prepend them to the args
		if key == "positional" {
			if v, ok := value.([]any); ok {
				for _, val := range v {
					args = append(args, fmt.Sprintf("%s", val))
				}
			} else {
				fmt.Fprintf(os.Stderr, "Error: key 'positional' has a value that is not a list\n")
				return 1
			}
			continue
		}

		switch v := value.(type) {
		case []any:
			// Join the values with commas
			var values []string
			for _, val := range v {
				values = append(values, fmt.Sprintf("%s", val))
			}
			args = append(args, fmt.Sprintf("--%s=%s", key, strings.Join(values, ",")))
		case bool:
			// If the value is a boolean, add it as a flag, otherwise leave it out
			if v {
				args = append(args, fmt.Sprintf("--%s", key))
			}
		case any:
			args = append(args, fmt.Sprintf("--%s=%s", key, v))
		}
	}

	cmd := exec.Command("gh", append(ghCommands, args...)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			if status, ok := exitError.Sys().(interface{ ExitStatus() int }); ok {
				return exitCode(status.ExitStatus())
			}
			return exitCode(exitError.ExitCode())
		}
		return 1
	}

	return 0
}
