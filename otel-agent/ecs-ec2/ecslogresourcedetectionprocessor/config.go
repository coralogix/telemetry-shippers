package ecslogresourcedetectionprocessor

import (
	"regexp"
)

type Config struct {
	// Attributes is a list of attribute pattern to be added to the resource
	Attributes []string `mapstructure:"attributes"`
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
