all: clean compile

compile:
	@go mod vendor
	@go build -buildmode=c-shared -ldflags "-s -w" -mod=vendor -o out_coralogix.so .

clean:
	@rm -rf out_coralogix.h src bin vendor

