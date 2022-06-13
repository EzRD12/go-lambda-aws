package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type PostInput struct {
	Name     string `json:"name"`
	LastName string `json:"lastname"`
}

type MyResponse struct {
	Message string `json:"message response"`
}

func main() {
	log.Printf("EVENT: Lambda function started")
	lambda.Start(HandleLambdaEvent)
}

func HandleLambdaEvent(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	eventJson, _ := json.MarshalIndent(request, "", "  ")
	log.Printf("EVENT: %s", eventJson)

	jsonInput := &PostInput{}
	err := json.Unmarshal([]byte(request.Body), jsonInput)

	if err != nil {
		log.Printf("Error: %s", err)
		log.Printf("Error: %s", err)
		return events.APIGatewayProxyResponse{
			StatusCode: 400,
			Body:       "Error",
		}, nil
	}

	name := jsonInput.Name
	lastName := jsonInput.LastName

	body := fmt.Sprintf("{\"message\": \"Hello from my lambda Sr/Sra %s %s\"}", name, lastName)
	return events.APIGatewayProxyResponse{
		Body:       body,
		StatusCode: 202,
	}, nil
}
