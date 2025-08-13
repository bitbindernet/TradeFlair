param(
    [switch]$prod
)

$SECRETS=aws secretsmanager get-secret-value --secret-id "REDDIT-CCAutoFlair" --region us-east-2 --query SecretString --output json | convertfrom-json | convertfrom-json -AsHashtable 

$ENV:MYSQL_USER = $SECRETS.MYSQL_USER 
$ENV:MYSQL_PASSWORD = $SECRETS.MYSQL_PASSWORD
$ENV:MYSQL_SERVER = $SECRETS.MYSQL_SERVER
$ENV:MYSQL_SERVER_PORT = $SECRETS.MYSQL_SERVER_PORT

