# go-lambda-aws
 A test project using Golang to create an AWS lambda function and deploy it using terraform

# Release

1. Use the following command to build the service and create the executable file:

For mac or Linux bits
```
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o ../publish/lambda_function -ldflags '-w' ../src/main.go
```

For Window 64 bits

```
GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -o ../publish/lambda_function -ldflags '-w' ../src/main.go
```

2. Open a terminal in the deploy directory and run the `terraform apply` command and enter the info for the access_key, access_secret and aws_region to deploy this lambda function