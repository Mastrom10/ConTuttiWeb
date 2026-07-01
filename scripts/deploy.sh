#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AWS="${AWS:-$HOME/.local/bin/aws}"
export AWS_PROFILE="${AWS_PROFILE:-contutti}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# shellcheck disable=SC1091
source "$ROOT_DIR/.env.aws"
# shellcheck disable=SC1091
source "$ROOT_DIR/.env.resend"

DOMAIN="contuttipizzaparty.com"
WWW_DOMAIN="www.contuttipizzaparty.com"
HOSTED_ZONE_ID="Z02034301Y094BS9DFTIE"
ACCOUNT_ID="${AWS_ACCOUNT_ID}"
BUCKET_NAME="contuttipizzaparty-web-${ACCOUNT_ID}"
LAMBDA_NAME="contuttipizzaparty-contact-form"
ROLE_NAME="contuttipizzaparty-lambda-role"
API_NAME="contuttipizzaparty-contact-api"
DEPLOYMENT_ENV="$ROOT_DIR/infra/deployment.env"

log() { echo "[deploy] $*"; }

save_deployment_env() {
  cat > "$DEPLOYMENT_ENV" <<EOF
AWS_ACCOUNT_ID=${ACCOUNT_ID}
AWS_REGION=${AWS_DEFAULT_REGION}
DOMAIN=${DOMAIN}
BUCKET_NAME=${BUCKET_NAME}
HOSTED_ZONE_ID=${HOSTED_ZONE_ID}
LAMBDA_NAME=${LAMBDA_NAME}
API_NAME=${API_NAME}
EOF
}

ensure_s3_bucket() {
  if "$AWS" s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    log "Bucket S3 ya existe: $BUCKET_NAME"
  else
    log "Creando bucket S3: $BUCKET_NAME"
    if [ "$AWS_DEFAULT_REGION" = "us-east-1" ]; then
      "$AWS" s3api create-bucket --bucket "$BUCKET_NAME"
    else
      "$AWS" s3api create-bucket --bucket "$BUCKET_NAME" \
        --create-bucket-configuration "LocationConstraint=$AWS_DEFAULT_REGION"
    fi
  fi

  "$AWS" s3api put-public-access-block --bucket "$BUCKET_NAME" \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
}

ensure_acm_validation_records() {
  local records
  records=$("$AWS" acm describe-certificate --region us-east-1 --certificate-arn "$CERT_ARN" \
    --query 'Certificate.DomainValidationOptions' --output json)

  HOSTED_ZONE_ID="$HOSTED_ZONE_ID" AWS="$AWS" AWS_PROFILE="$AWS_PROFILE" \
    RECORDS_JSON="$records" python3 <<'PY'
import json, os, subprocess

records = json.loads(os.environ["RECORDS_JSON"])
aws = os.environ["AWS"]
profile = os.environ["AWS_PROFILE"]
zone = os.environ["HOSTED_ZONE_ID"]

for item in records:
    opt = item.get("ResourceRecord") or {}
    name = opt.get("Name")
    value = opt.get("Value")
    if not name or not value:
        continue
    change = {
        "Comment": "ACM validation",
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": name,
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [{"Value": value}],
            },
        }],
    }
    path = "/tmp/acm-validation.json"
    with open(path, "w") as f:
        json.dump(change, f)
    subprocess.run([
        aws, "route53", "change-resource-record-sets",
        "--hosted-zone-id", zone,
        "--change-batch", f"file://{path}",
        "--profile", profile,
    ], check=True)
    print(f"[deploy] Registro ACM agregado: {name}")
PY
}

ensure_acm_certificate() {
  local existing
  existing=$("$AWS" acm list-certificates --region us-east-1 \
    --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" --output text)

  if [ "$existing" != "None" ] && [ -n "$existing" ]; then
    CERT_ARN="$existing"
    log "Certificado ACM existente: $CERT_ARN"
  else
    log "Solicitando certificado ACM para ${DOMAIN} y ${WWW_DOMAIN}"
    CERT_ARN=$("$AWS" acm request-certificate \
      --region us-east-1 \
      --domain-name "$DOMAIN" \
      --subject-alternative-names "$WWW_DOMAIN" \
      --validation-method DNS \
      --query CertificateArn --output text)
    sleep 5
  fi

  log "Configurando registros DNS de validación ACM..."
  ensure_acm_validation_records

  log "Esperando emisión del certificado ACM (puede tardar 1-5 min)..."
  for i in $(seq 1 40); do
    local status
    status=$("$AWS" acm describe-certificate --region us-east-1 --certificate-arn "$CERT_ARN" \
      --query Certificate.Status --output text)
    if [ "$status" = "ISSUED" ]; then
      log "Certificado emitido."
      return
    fi
    log "Estado ACM: ${status} (intento ${i}/40)..."
    sleep 15
  done
  echo "Timeout esperando certificado ACM" >&2
  exit 1
}

ensure_cloudfront_oac() {
  local existing
  existing=$("$AWS" cloudfront list-origin-access-controls --query "OriginAccessControlList.Items[?Name=='${BUCKET_NAME}-oac'].Id | [0]" --output text)
  if [ "$existing" != "None" ] && [ -n "$existing" ]; then
    OAC_ID="$existing"
  else
    OAC_ID=$("$AWS" cloudfront create-origin-access-control --origin-access-control-config "{
      \"Name\": \"${BUCKET_NAME}-oac\",
      \"Description\": \"OAC for ${BUCKET_NAME}\",
      \"SigningProtocol\": \"sigv4\",
      \"SigningBehavior\": \"always\",
      \"OriginAccessControlOriginType\": \"s3\"
    }" --query OriginAccessControl.Id --output text)
  fi
  log "OAC ID: $OAC_ID"
}

ensure_cloudfront_distribution() {
  local origin_domain="${BUCKET_NAME}.s3.${AWS_DEFAULT_REGION}.amazonaws.com"
  local existing
  existing=$("$AWS" cloudfront list-distributions --query "DistributionList.Items[?Comment=='contuttipizzaparty-web'].Id | [0]" --output text)

  apply_bucket_policy() {
    local policy_file="/tmp/bucket-policy.json"
    cat > "$policy_file" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontServicePrincipal",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${CF_ID}"
      }
    }
  }]
}
EOF
    "$AWS" s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "file://${policy_file}"
  }

  if [ "$existing" != "None" ] && [ -n "$existing" ]; then
    CF_ID="$existing"
    CF_DOMAIN=$("$AWS" cloudfront get-distribution --id "$CF_ID" --query 'Distribution.DomainName' --output text)
    log "CloudFront existente: $CF_ID ($CF_DOMAIN)"
    apply_bucket_policy
    return
  fi

  local caller_ref="contuttipizzaparty-$(date +%s)"
  local config_file="/tmp/cf-config.json"
  cat > "$config_file" <<EOF
{
  "CallerReference": "${caller_ref}",
  "Comment": "contuttipizzaparty-web",
  "Enabled": true,
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [{
      "Id": "s3-${BUCKET_NAME}",
      "DomainName": "${origin_domain}",
      "OriginAccessControlId": "${OAC_ID}",
      "S3OriginConfig": { "OriginAccessIdentity": "" }
    }]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-${BUCKET_NAME}",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] }
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  "Aliases": {
    "Quantity": 2,
    "Items": ["${DOMAIN}", "${WWW_DOMAIN}"]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "${CERT_ARN}",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "CustomErrorResponses": {
    "Quantity": 2,
    "Items": [
      { "ErrorCode": 403, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 0 },
      { "ErrorCode": 404, "ResponsePagePath": "/index.html", "ResponseCode": "200", "ErrorCachingMinTTL": 0 }
    ]
  },
  "PriceClass": "PriceClass_100"
}
EOF

  CF_ID=$("$AWS" cloudfront create-distribution --distribution-config "file://${config_file}" \
    --query 'Distribution.Id' --output text)
  CF_DOMAIN=$("$AWS" cloudfront get-distribution --id "$CF_ID" --query 'Distribution.DomainName' --output text)
  log "CloudFront creado: $CF_ID ($CF_DOMAIN)"
  apply_bucket_policy
}

ensure_lambda_role() {
  local role_arn
  if "$AWS" iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    role_arn=$("$AWS" iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)
  else
    local trust='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    role_arn=$("$AWS" iam create-role --role-name "$ROLE_NAME" \
      --assume-role-policy-document "$trust" --query Role.Arn --output text)
    "$AWS" iam attach-role-policy --role-name "$ROLE_NAME" \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    sleep 10
  fi
  LAMBDA_ROLE_ARN="$role_arn"
}

deploy_lambda() {
  local zip_file="/tmp/contuttipizzaparty-contact-form.zip"
  (cd "$ROOT_DIR/infra/lambda/contact-form" && zip -q "$zip_file" index.js)

  if "$AWS" lambda get-function --function-name "$LAMBDA_NAME" >/dev/null 2>&1; then
    "$AWS" lambda update-function-code --function-name "$LAMBDA_NAME" --zip-file "fileb://${zip_file}" >/dev/null
    sleep 3
    "$AWS" lambda update-function-configuration \
      --function-name "$LAMBDA_NAME" \
      --runtime nodejs20.x \
      --handler index.handler \
      --role "$LAMBDA_ROLE_ARN" \
      --timeout 15 \
      --environment "Variables={RESEND_API_KEY=${RESEND_API_KEY},RESEND_FROM_EMAIL=${RESEND_FROM_EMAIL},RESEND_TO_EMAIL=${RESEND_TO_EMAIL}}" >/dev/null
  else
    "$AWS" lambda create-function \
      --function-name "$LAMBDA_NAME" \
      --runtime nodejs20.x \
      --role "$LAMBDA_ROLE_ARN" \
      --handler index.handler \
      --timeout 15 \
      --zip-file "fileb://${zip_file}" \
      --environment "Variables={RESEND_API_KEY=${RESEND_API_KEY},RESEND_FROM_EMAIL=${RESEND_FROM_EMAIL},RESEND_TO_EMAIL=${RESEND_TO_EMAIL}}" >/dev/null
  fi
  LAMBDA_ARN=$("$AWS" lambda get-function --function-name "$LAMBDA_NAME" --query Configuration.FunctionArn --output text)
  log "Lambda desplegada: $LAMBDA_ARN"
}

ensure_api_gateway() {
  local api_id
  api_id=$("$AWS" apigatewayv2 get-apis --query "Items[?Name=='${API_NAME}'].ApiId | [0]" --output text)

  if [ "$api_id" = "None" ] || [ -z "$api_id" ]; then
    api_id=$("$AWS" apigatewayv2 create-api \
      --name "$API_NAME" \
      --protocol-type HTTP \
      --cors-configuration "AllowOrigins=https://${DOMAIN},https://${WWW_DOMAIN},AllowMethods=POST,OPTIONS,AllowHeaders=Content-Type" \
      --query ApiId --output text)
  fi

  local integration_id
  integration_id=$("$AWS" apigatewayv2 create-integration \
    --api-id "$api_id" \
    --integration-type AWS_PROXY \
    --integration-uri "$LAMBDA_ARN" \
    --payload-format-version 2.0 \
    --query IntegrationId --output text 2>/dev/null || true)

  if [ -z "$integration_id" ] || [ "$integration_id" = "None" ]; then
    integration_id=$("$AWS" apigatewayv2 get-integrations --api-id "$api_id" --query 'Items[0].IntegrationId' --output text)
  fi

  local route_exists
  route_exists=$("$AWS" apigatewayv2 get-routes --api-id "$api_id" --query "Items[?RouteKey=='POST /contact'].RouteId | [0]" --output text)
  if [ "$route_exists" = "None" ] || [ -z "$route_exists" ]; then
    "$AWS" apigatewayv2 create-route --api-id "$api_id" --route-key "POST /contact" --target "integrations/${integration_id}" >/dev/null
  fi

  local opt_route
  opt_route=$("$AWS" apigatewayv2 get-routes --api-id "$api_id" --query "Items[?RouteKey=='OPTIONS /contact'].RouteId | [0]" --output text)
  if [ "$opt_route" = "None" ] || [ -z "$opt_route" ]; then
    "$AWS" apigatewayv2 create-route --api-id "$api_id" --route-key "OPTIONS /contact" --target "integrations/${integration_id}" >/dev/null
  fi

  local stage_exists
  stage_exists=$("$AWS" apigatewayv2 get-stages --api-id "$api_id" --query "Items[?StageName=='\$default'].StageName | [0]" --output text)
  if [ "$stage_exists" = "None" ] || [ -z "$stage_exists" ]; then
    "$AWS" apigatewayv2 create-stage --api-id "$api_id" --stage-name '$default' --auto-deploy >/dev/null
  fi

  "$AWS" lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id "apigateway-${api_id}" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:${api_id}/*/*/contact" >/dev/null 2>&1 || true

  API_URL="https://${api_id}.execute-api.${AWS_DEFAULT_REGION}.amazonaws.com/contact"
  log "API Gateway URL: $API_URL"
}

update_config_js() {
  cat > "$ROOT_DIR/js/config.js" <<EOF
window.CONTUTTI_CONFIG = {
  apiUrl: "${API_URL}",
};
EOF
}

sync_static_site() {
  log "Subiendo sitio estático a S3..."
  "$AWS" s3 sync "$ROOT_DIR" "s3://${BUCKET_NAME}" \
    --delete \
    --exclude ".git/*" \
    --exclude ".venv/*" \
    --exclude ".cursor/*" \
    --exclude "imagenesNuevas/*" \
    --exclude "php/*" \
    --exclude "infra/*" \
    --exclude "scripts/*" \
    --exclude "aws/*" \
    --exclude ".env*" \
    --exclude ".gitignore" \
    --exclude "agents.md" \
    --exclude "memory.md" \
    --exclude "README.md" \
    --cache-control "public,max-age=3600"
}

upsert_route53_alias() {
  local name="$1"
  local change_batch
  change_batch=$(cat <<EOF
{
  "Comment": "Alias to CloudFront",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${name}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "${CF_DOMAIN}",
          "EvaluateTargetHealth": false
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${name}",
        "Type": "AAAA",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "${CF_DOMAIN}",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF
)
  echo "$change_batch" > /tmp/route53-alias.json
  "$AWS" route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch file:///tmp/route53-alias.json
}

invalidate_cloudfront() {
  log "Invalidando caché CloudFront..."
  "$AWS" cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*" >/dev/null
}

main() {
  log "Iniciando deploy Con Tutti Pizza Party"
  export HOSTED_ZONE_ID
  save_deployment_env
  ensure_s3_bucket
  ensure_acm_certificate
  ensure_cloudfront_oac
  ensure_cloudfront_distribution
  ensure_lambda_role
  deploy_lambda
  ensure_api_gateway
  update_config_js
  sync_static_site
  upsert_route53_alias "${DOMAIN}."
  upsert_route53_alias "${WWW_DOMAIN}."
  invalidate_cloudfront

  {
    echo "CERT_ARN=${CERT_ARN}"
    echo "CF_ID=${CF_ID}"
    echo "CF_DOMAIN=${CF_DOMAIN}"
    echo "API_URL=${API_URL}"
    echo "BUCKET_NAME=${BUCKET_NAME}"
    echo "LAMBDA_ARN=${LAMBDA_ARN}"
  } >> "$DEPLOYMENT_ENV"

  log "Deploy completado."
  log "Sitio: https://${DOMAIN}"
  log "API: ${API_URL}"
}

main "$@"
