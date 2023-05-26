provider "aws" {

  region = "us-east-1"
}

# ----- LAMBDA1 -----
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_s3_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}


# data "archive_file" "zip_python_code" {
#   type        = "zip"
#   source_dir  = "${path.module}/python/"
#   output_path = "${path.module}/python/lambda-pipelineC.zip"
# }

resource "aws_lambda_function" "lambda-pipelineC" {
  filename      = "${path.module}/python/funcao.zip"
  function_name = "lambda-pipelineC"
  role          = aws_iam_role.lambda_role.arn
  handler       = "funcao.lambda_handler" # <nome_do_arquivo.py>.<nome_da_função_dentro_do_arquivo>
  runtime       = "python3.8"
}

# ----- S31 -----
# Criação do bucket do S3 para o CodePipeline ok
resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = "my-pipeline-bucketykaro" # Substitua pelo nome desejado
}

# resource "aws_s3_bucket_versioning" "versioning_example" {
#   bucket = aws_s3_bucket.pipeline_bucket.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# ----- codecommit1 -----
# Criação do repositório do CodeCommit
resource "aws_codecommit_repository" "my_repo" {
  repository_name = "my-repositorio1"
  default_branch  = "master"
}


# resource "aws_codecommit_branch" "my_branch" {
#   repository_name = aws_codecommit_repository.my_repo.repository_name
#   branch_name     = "my-branch"
# }

# ----- codebuild1 -----
# Criação do projeto do CodeBuild
resource "aws_codebuild_project" "my_project" {
  name          = "my-project" # Substitua pelo nome desejado
  description   = "My CodeBuild project"
  build_timeout = 60

  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  #   esta na documentacao nao sei se precisa
  cache {
    type     = "S3"
    location = aws_s3_bucket.pipeline_bucket.bucket
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0" # image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    #privileged_mode             = true

  }

  #   logs_config {
  #     cloudwatch_logs {
  #       group_name  = "log-group"
  #       stream_name = "log-stream"
  #     }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml" # Substitua pelo caminho do arquivo buildspec.yml do seu projeto
    git_clone_depth = 1
  }
}


# Criação da função do CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"
  # doc// assume_role_policy = data.aws_iam_policy_document.assume_role.json
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# ----- codedeploy1 -----
# Criação do aplicativo do CodeDeploy
resource "aws_codedeploy_app" "my_app" {
  compute_platform = "Server" # pode ser que tenha que colocar Lambda
  name             = "my-app" # Substitua pelo nome desejado
}

# Criação do grupo de implantação do CodeDeploy
resource "aws_codedeploy_deployment_group" "my_deployment_group" {
  app_name              = aws_codedeploy_app.my_app.name
  deployment_group_name = "my-deployment-group" # Substitua pelo nome desejado
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  # no gpt tinha e na documentacao nao tem 
  #deployment_config_name = "CodeDeployDefault.AllAtOnce"
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_iam_role" "codedeploy_role" {
  name = "codedeploy-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Criação da função do CodePipeline
# a policy nao esta redonda
resource "aws_iam_role" "pipeline_role" {
  name               = "codepipeline-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  inline_policy {
    name   = "codepipeline_execute_policy"
    policy = data.aws_iam_policy_document.codepipeline.json
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid = "CodePipelineAllow"

    actions = [
      "s3:*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "iam:PassRole",
    ]

    resources = [
      aws_iam_role.codebuild_role.arn,
    ]
  }

  statement {
    actions = [
      "codecommit:BatchGet*",
      "codecommit:BatchDescribe*",
      "codecommit:Describe*",
      "codecommit:Get*",
      "codecommit:List*",
      "codecommit:GitPull",
      "codecommit:UploadArchive",
      "codecommit:GetBranch",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "codebuild:StartBuild",
      "codebuild:StopBuild",
      "codebuild:BatchGetBuilds",
    ]

    resources = [
      aws_codebuild_project.my_project.arn,
      #aws_codebuild_project.terraform_plan.arn,
    ]
  }
}

# ----- codedeploy1 -----
# Criação do pipeline do CodePipeline
resource "aws_codepipeline" "my_pipeline" {
  name     = "my-pipeline" # Substitua pelo nome desejado
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_bucket.id
    type     = "S3"
  }

  stage {
    name = "Clone"

    action {
      name     = "SourceAction" # doc name             = "Source"
      category = "Source"
      owner    = "AWS"
      provider = "CodeCommit"
      #branch           = "Master"
      version          = "1"
      output_artifacts = ["source_output"] # gpt output_artifacts = ["SourceOutput"]

      configuration = {
        RepositoryName = aws_codecommit_repository.my_repo.repository_name # esta diferente da documentacao
        BranchName     = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build" # gpt BuildAction
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.my_project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "LambdaAction"
      category        = "Invoke"
      owner           = "AWS"
      provider        = "Lambda"
      input_artifacts = ["build_output"]
      # output_artifacts = ["build_output"]
      version = "1"

      configuration = {
        FunctionName = "my-lambda-function"
        #DeploymentGroupName = "additional-parameters"
      }
    }
  }
}



# stage {
#     name = "Deploy"

#     action {
#       name            = "DeployAction"
#       category        = "Deploy"
#       owner           = "AWS"
#       provider        = "CodeDeploy"
#       input_artifacts = ["source_output"]
#       # output_artifacts = ["build_output"]
#       version = "1"

#       configuration = {
#         ApplicationName     = aws_codedeploy_app.my_app.name
#         DeploymentGroupName = aws_codedeploy_deployment_group.my_deployment_group.deployment_group_name
#       }
#     }
#   }
