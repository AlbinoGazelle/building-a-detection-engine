# Building a Detection Engine
This repository holds the infrastructure to build the Detection Engine I'm in the process of creating in my ongoing "Building a Detection Engine" blog series.  
[Part 1: What is a Detection Engine?](https://medium.com/@nburns9922/building-a-detection-engine-part-1-what-is-a-detection-engine-e223119fad7e)  
Part 2: Collection  

## Usage
**Clone Repository**
```
git clone https://github.com/AlbinoGazelle/building-a-detection-engine.git
```
**Update Variables.tf**  
Update `bucket_name` and `tf_iam_profile` in `variables.tf` to match your environment. `bucket_name` must be a globally unique S3 bucket name and `tf_iam_profile` must be the name of an existing set of IAM credentials.  

**Initialize Terraform**  
```
terraform init
```
**Plan Infrastructure**  
```
terraform plan
```
**Generate Infrastructure**  
```
terraform apply
```
**Destroy Infrastructure**  
```
terraform destroy
```

