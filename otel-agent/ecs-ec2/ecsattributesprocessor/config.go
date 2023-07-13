package ecsattributesprocessor

import (
	"errors"
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
	ContainerID     `mapstructure:"container_id"`
	attrExpressions []*regexp.Regexp // store compiled regexes
}

type ContainerID struct {
	Sources []string `mapstructure:"sources"`
}

// init - initialise config, returns error
func (c *Config) init() error {
	// check ContainerID sources
	if len(c.ContainerID.Sources) == 0 {
		return errors.New("atleast one container ID source must be specified. [container_id.sources]")
	}

	// validate attribute regex
	for _, expr := range c.Attributes {
		r, err := regexp.Compile(expr)
		if err != nil {
			return fmt.Errorf("invalid expression found under attributes pattern %s - %w", expr, err)
		}

		c.attrExpressions = append(c.attrExpressions, r)
	}
	return nil
}

func (c *Config) allowAttr(k string) (bool, error) {
	// if no attribue patterns are present, return true always
	if len(c.attrExpressions) == 0 {
		return true, nil
	}

	for _, re := range c.attrExpressions {
		if re.MatchString(k) {
			return true, nil
		}

	}
	return false, nil
}
