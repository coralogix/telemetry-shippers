package ecsattributesprocessor

import (
	"fmt"
	"regexp"
)

type Config struct {
	// Attributes is a list of attribute pattern to be added to the resource
	Attributes []string `mapstructure:"attributes"`

	// Source fields specifies what resource attribute field to read the
	// container ID
	// container_id:
	//   sources:
	//     - "log.file.name"
	// 	   - "container.id"
	ContainerID `mapstructure:"container_id"`
}

type ContainerID struct {
	Sources []string `mapstructure:"sources"`
}

func (c *Config) validate() error {
	// check ContainerID sources
	if len(c.ContainerID.Sources) == 0 {
		return fmt.Errorf("atleast one container ID source must be specified. [container_id.sources]")
	}

	// validate attribute regex
	for _, expr := range c.Attributes {
		if _, err := regexp.Compile(expr); err != nil {
			return fmt.Errorf("invalid expression found under attributes pattern %s - %s", expr, err)
		}
	}
	return nil
}

func (c *Config) allowAttr(k string) (ok bool, err error) {
	// if no attribue patterns are present, return true always
	if len(c.Attributes) == 0 {
		ok = true
	}

	for _, expr := range c.Attributes {
		re, err := regexp.Compile(expr)
		if err != nil {
			return ok, err
		}

		if re.MatchString(k) {
			ok = true
			break
		}

	}
	return
}
