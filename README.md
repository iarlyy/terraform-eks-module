# module_name
Description here

## Usage

Include the code below as a module in the terraform code:
```hcl
module "module_name" {
  environment     = "${var.environment}"
}
```

## Input

|  Name                  |                    Description                                |
|:-----------------------|:--------------------------------------------------------------|
| environment            | Environment (Ex: staging, prod)                               |

## Output

| Name                   |        Description                                            |
|:-----------------------|:--------------------------------------------------------------|
| id                     | ID                                                            |
