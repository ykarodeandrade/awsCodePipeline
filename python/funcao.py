import json
import boto3

def lambda_handler(event, context):
    # Executar a lógica da função Lambda
    
    # Chamada para PutJobSuccessResult
    codepipeline = boto3.client('codepipeline')
    job_id = event['CodePipeline.job']['id']
    codepipeline.put_job_success_result(jobId=job_id)
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
