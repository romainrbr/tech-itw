# ingestGBFSData

This code allows you to deploy a Lambda function to AWS that will scrape a GBFS endpoint every minute, and store its content in a S3 bucket of your choice.



## Python script

The python code is stored in the `./src` folder.
`lambda_function.py` is the script itself.
`requirements.txt` contains the needed modules to run the lambda script.
`requirements-tests.txt` contains the needed modules to run the tests.
`tests.py` contains the tests.
`./testFiles` contains `.json` files used to mock GBFS endpoints.

### Run the script

To run the script, the Lambda function needs three parameters, set as env values:
- `endpointUrl` : url of the endpoint(s) to scrape (ex: `https://velib-metropole-opendata.smoove.pro/opendata/Velib_Metropole/station_status.json`)
- `endpointName` : name of the endpoint(s) to be scrapped (ex : `paris`)
- `bucketName` : the name of the bucket in which the GBFS files will be saved (ex: `gbfsdata`)


### Test the script

To test the script, you can just run `python tests.py`


## Terraform

The terraform part is composed of 3 files : 
- `variables.tf` : a list of variables that can be changed to define what to scrape, and how to store data
- `main.tf` : terraform's main set of configuration for the module
- `lambda.tf` : all configuration related to the creation of the lambda script, and everything related to it (s3 bucket, cloudwatch logs, iams, etc ...)

To replicate the terraform setup : 
1. Configure your AWS credentials (`~/.aws/credentials`)
2. Edit the `remote` settings in `main.tf`. The backend part can be deleted if running locally.
3. Edit `variables.tf` accordingly (add or remove endpoints, change bucket name, etc ..)
4. Run `terraform init`
5. Run `terraform apply`
6. You should now have all resources available on your AWS account


## AWS

The following services will be created on AWS : 
- 1 S3 bucket, on which all endpoints will write
- 1 Lambda script per endpoint to scrape
- 1 Cloudwatch log group per endpoint to scrape (automatically created when launching a Lambda script)
- 1 Cloudwatch event rule (to trigger the Lambda scripts every minute), associated with every Lambda script created
- IAM policies to allow all components to communicate with each other
- 1 Cloudwatch alarm, alerting us when the Lambda script fails (it is possible to suscribe to the SNS topic with any monitoring tool, or just add an email notification)

## Github actions

The current setup is also available on Github actions.

It allows us to : 
- Run tests on the pushed code (either directly, or through PR's)
  - On the Python script (linting and testing)
  - On the terraform module (formatting, init, validate)
- Automatically deploy to production when tests are working


To be setup, the Github repos needs the following secrets to be defined : 
- `AWS_ACCESS_KEY_ID` : AWS ID to an IAM that can create/destroy all needed resources
- `AWS_SECRET_ACCESS_KEY` : AWS secret o an IAM that can create/destroy all needed resources
- `TF_API_TOKEN` : Terraform cloud's API token for a workspace (defined in `main.tf`)

