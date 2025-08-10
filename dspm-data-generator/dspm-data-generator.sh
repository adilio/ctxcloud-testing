#!/bin/bash

# DSPM Realistic Test Data Generator
# Generates realistic-looking synthetic test data for Data Security Posture Management testing
# WARNING: This is for testing purposes only - do not use with real data

set -e

# Configuration
OUTPUT_DIR="dspm_test_data"
DEFAULT_RECORDS=100  # Changed from 1000 to 100
AWS_UPLOAD=false
S3_BUCKET=""
MAKE_PUBLIC=false
AWS_REGION=${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null)}
AWS_REGION=${AWS_REGION:-us-east-1}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[38;5;75m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper function to print colored output
print_status() {
    echo -e "${GREEN}✅ [INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️ [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1"
}

# Arrays for realistic data generation
FIRST_NAMES=("James" "Mary" "John" "Patricia" "Robert" "Jennifer" "Michael" "Linda" "William" "Elizabeth" "David" "Barbara" "Richard" "Susan" "Joseph" "Jessica" "Thomas" "Sarah" "Charles" "Karen")
LAST_NAMES=("Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis" "Rodriguez" "Martinez" "Hernandez" "Lopez" "Gonzalez" "Wilson" "Anderson" "Thomas" "Taylor" "Moore" "Jackson" "Martin")
DOMAINS=("gmail.com" "yahoo.com" "outlook.com" "company.org" "business.co.jp" "test.net")
DIAGNOSES=("Hypertension" "Asthma" "Diabetes" "Migraine" "COVID-19" "Anxiety" "Depression" "Allergy" "Flu" "COPD")
LAB_RESULTS=("WBC: 8.5 K/uL" "HbA1c: 7.5%" "BP: 120/80 mmHg" "WBC: 11.2 K/uL" "HbA1c: 6.2%" "BP: 145/95 mmHg" "Glucose: 110 mg/dL" "Glucose: 180 mg/dL" "Cholesterol: 200 mg/dL" "Cholesterol: 240 mg/dL")
CITIES=("New York" "Los Angeles" "Chicago" "Houston" "Phoenix" "Philadelphia" "San Antonio" "San Diego" "Dallas" "San Jose")
STATES=("CA" "TX" "FL" "NY" "PA" "IL" "OH" "GA" "NC" "MI")
STREETS=("Main" "Oak" "Pine" "Maple" "Cedar" "Elm" "Washington" "Lake" "Hill" "Park")
CREDIT_CARD_TYPES=("Visa" "MasterCard" "American Express" "Discover")
MEDICATIONS=("Lisinopril" "Atorvastatin" "Metformin" "Amlodipine" "Albuterol" "Omeprazole" "Losartan" "Simvastatin" "Gabapentin" "Hydrochlorothiazide")
EMPLOYMENT_STATUSES=("Full-time" "Part-time" "Contractor" "Freelance" "Intern")
JOB_TITLES=("Software Engineer" "Data Analyst" "Product Manager" "UX Designer" "DevOps Engineer" "Security Specialist" "Database Admin" "Network Engineer")
COMPANIES=("TechCorp" "DataSystems" "SecureNet" "CloudInnovate" "FutureTech" "ByteSolutions" "InfoSecure" "DigitalFortress")
SECRET_TYPES=("API_KEY" "GITHUB_TOKEN" "AWS_SECRET" "DATABASE_PASSWORD" "SSH_KEY" "ENCRYPTION_KEY")
ENVIRONMENTS=("Production" "Staging" "Development" "Testing")
SERVICES=("UserService" "PaymentService" "AuthService" "Database" "Analytics" "EmailService")
OWNERS=("dev-team@company.com" "api-team@company.com" "infra@company.com" "security@company.com")

# Count variables
PHI_COUNT=0
SECRETS_COUNT=0
FINANCIAL_COUNT=0
PCI_COUNT=0
PII_COUNT=0
MIXED_COUNT=0

# Function to generate random first names
generate_first_name() {
    echo "${FIRST_NAMES[$RANDOM % ${#FIRST_NAMES[@]}]}"
}

# Function to generate random last names
generate_last_name() {
    echo "${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}"
}

# Function to generate IP addresses
generate_ip_address() {
    printf "%d.%d.%d.%d" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

# Function to generate email addresses
generate_email() {
    local first_name=$(echo "$(generate_first_name)" | tr '[:upper:]' '[:lower:]')
    local last_name=$(echo "$(generate_last_name)" | tr '[:upper:]' '[:lower:]')
    local domain=${DOMAINS[$RANDOM % ${#DOMAINS[@]}]}
    local username="${first_name}.${last_name}$((RANDOM % 100))"
    echo "${username}@${domain}"
}

# Function to generate IBAN numbers
generate_iban() {
    local countries=("DE" "FR" "GB" "IT" "ES" "PL" "NL")
    local country=${countries[$RANDOM % ${#countries[@]}]}
    local iban_length=22
    local bban_length=$((iban_length - 4))
    local bban=$(head /dev/urandom | LC_CTYPE=C tr -dc '0-9' | head -c $bban_length)
    echo "${country}00${bban}"
}

# Function to generate gender
generate_gender() {
    local genders=("Male" "Female" "Other")
    echo ${genders[$RANDOM % ${#genders[@]}]}
}

# Function to generate credit card numbers
generate_credit_card() {
    local prefixes=("4" "51" "52" "53" "54" "55" "34" "37" "6011")
    local prefix=${prefixes[$RANDOM % ${#prefixes[@]}]}
    local length=16
    if [[ "$prefix" == "34" || "$prefix" == "37" ]]; then
        length=15  # American Express
    elif [[ "$prefix" == "6011" ]]; then
        length=16  # Discover
    fi
    
    local card_number="$prefix"
    while [ ${#card_number} -lt $((length - 1)) ]; do
        card_number+=$((RANDOM % 10))
    done
    
    # Luhn algorithm for check digit
    local sum=0
    local num_digits=${#card_number}
    local parity=$(( (num_digits + 1) % 2 ))
    
    for ((i=0; i<num_digits; i++)); do
        digit=${card_number:$i:1}
        if [ $((i % 2)) -eq $parity ]; then
            digit=$((digit * 2))
            if [ $digit -gt 9 ]; then
                digit=$((digit - 9))
            fi
        fi
        sum=$((sum + digit))
    done
    
    local check_digit=$(( (10 - (sum % 10)) % 10 ))
    echo "$card_number$check_digit"
}

# Function to generate internal IP addresses
generate_internal_ip() {
    local ips=("10" "192.168" "172.16" "172.17" "172.18" "172.19" "172.20" "172.21" "172.22" "172.23" "172.24" "172.25" "172.26" "172.27" "172.28" "172.29" "172.30" "172.31")
    local base=${ips[$RANDOM % ${#ips[@]}]}
    echo "${base}.$((RANDOM % 256)).$((RANDOM % 256))"
}

# Function to generate SSN
generate_ssn() {
    local area=$((RANDOM % 899 + 1))
    [ $area -eq 666 ] && area=665  # Avoid invalid SSN range
    local group=$((RANDOM % 99 + 1))
    local serial=$((RANDOM % 9999 + 1))
    printf "%03d-%02d-%04d" $area $group $serial
}

# Function to create CSV file with headers
create_csv_file() {
    local filename="$1"
    local headers="$2"
    
    echo "$headers" > "$filename"
    print_status "Created CSV file: $filename"
}

# Function to generate PHI (Personal Health Info) data
generate_phi_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/phi_data.csv"
    
    print_status "Generating PHI data ($num_records records)..."
    
    create_csv_file "$filename" "ID,First_Name,Last_Name,Date_Of_Birth,MRN,Diagnosis,Medication,Lab_Result,Email,Phone,Address,Created_Date"
    
    for ((i=1; i<=num_records; i++)); do
        local dob_year=$((RANDOM % 70 + 1940))
        local dob_month=$(printf "%02d" $((RANDOM % 12 + 1)))
        local dob_day=$(printf "%02d" $((RANDOM % 28 + 1)))
        local diagnosis=${DIAGNOSES[$RANDOM % ${#DIAGNOSES[@]}]}
        local medication=${MEDICATIONS[$RANDOM % ${#MEDICATIONS[@]}]}
        local lab_result=${LAB_RESULTS[$RANDOM % ${#LAB_RESULTS[@]}]}
        local area_code=$((RANDOM % 800 + 200))
        local phone_prefix=$((RANDOM % 800 + 200))
        local phone_suffix=$((RANDOM % 9000 + 1000))
        local street_num=$((RANDOM % 9999 + 100))
        local street=${STREETS[$RANDOM % ${#STREETS[@]}]}
        local city=${CITIES[$RANDOM % ${#CITIES[@]}]}
        local state=${STATES[$RANDOM % ${#STATES[@]}]}
        local zip=$((RANDOM % 90000 + 10000))
        
        echo "$i,$(generate_first_name),$(generate_last_name),${dob_year}-${dob_month}-${dob_day},$((RANDOM % 90000000 + 10000000)),$diagnosis,$medication,$lab_result,$(generate_email),${area_code}-${phone_prefix}-${phone_suffix},${street_num} ${street} St, ${city}, ${state} ${zip},$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records PHI records in $filename"
    PHI_COUNT=$num_records
}

# Function to generate Developer Secrets (FIXED VERSION)
generate_secrets_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/secrets_data.csv"
    
    print_status "Generating Secrets data ($num_records records)..."
    
    create_csv_file "$filename" "ID,Type,Secret_Value,Environment,Service,Owner,Created_Date"
    
    # Character sets for different secret types
    local alphanum="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local base64_chars="${alphanum}+/="
    local special_chars="!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    for ((i=1; i<=num_records; i++)); do
        local type=${SECRET_TYPES[$RANDOM % ${#SECRET_TYPES[@]}]}
        local env=${ENVIRONMENTS[$RANDOM % ${#ENVIRONMENTS[@]}]}
        local service=${SERVICES[$RANDOM % ${#SERVICES[@]}]}
        local owner=${OWNERS[$RANDOM % ${#OWNERS[@]}]}
        local value=""
        
        case "$type" in
            "API_KEY") 
                # 32-character alphanumeric string
                value="api_"
                for ((j=0; j<32; j++)); do
                    value+=${alphanum:$((RANDOM % ${#alphanum})):1}
                done
                ;;
            "GITHUB_TOKEN") 
                # GitHub token pattern: ghp_ followed by 36 alphanumeric characters
                value="ghp_"
                for ((j=0; j<36; j++)); do
                    value+=${alphanum:$((RANDOM % ${#alphanum})):1}
                done
                ;;
            "AWS_SECRET") 
                # AWS secret pattern: 40 base64 characters
                value="aws."
                for ((j=0; j<40; j++)); do
                    value+=${base64_chars:$((RANDOM % ${#base64_chars})):1}
                done
                ;;
            "DATABASE_PASSWORD") 
                # Database password with special characters
                value="db-"
                for ((j=0; j<20; j++)); do
                    # Alternate between alphanumeric and special characters
                    if (( j % 3 == 0 )); then
                        value+=${special_chars:$((RANDOM % ${#special_chars})):1}
                    else
                        value+=${alphanum:$((RANDOM % ${#alphanum})):1}
                    fi
                done
                ;;
            "SSH_KEY") 
                # SSH public key pattern
                value="ssh-rsa AAAAB3"
                for ((j=0; j<200; j++)); do
                    if (( j % 64 == 0 && j > 0 )); then
                        value+=" "  # Add spaces periodically for readability
                    fi
                    value+=${base64_chars:$((RANDOM % ${#base64_chars})):1}
                done
                value+=" generated-key"
                ;;
            "ENCRYPTION_KEY") 
                # Encryption key pattern
                value="enc_"
                for ((j=0; j<48; j++)); do
                    value+=${alphanum:$((RANDOM % ${#alphanum})):1}
                done
                ;;
        esac
        
        echo "$i,$type,$value,$env,$service,$owner,$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records Secrets records in $filename"
    SECRETS_COUNT=$num_records
}

# Function to generate Financial data
generate_financial_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/financial_data.csv"
    
    print_status "Generating Financial data ($num_records records)..."
    
    create_csv_file "$filename" "ID,First_Name,Last_Name,Email,Credit_Card,Card_Type,Card_Expiry,IBAN,Account_Balance,Transaction_Amount,Transaction_Date,Created_Date"
    
    for ((i=1; i<=num_records; i++)); do
        local card_type=${CREDIT_CARD_TYPES[$RANDOM % ${#CREDIT_CARD_TYPES[@]}]}
        local expiry_month=$(printf "%02d" $((RANDOM % 12 + 1)))
        local expiry_year=$((RANDOM % 5 + 2025))
        local balance=$((RANDOM % 1000000 + 1000))
        local amount=$((RANDOM % 5000 + 10))
        local transaction_date=$(date -v-"$((RANDOM % 30))d" +%Y-%m-%d)
        
        echo "$i,$(generate_first_name),$(generate_last_name),$(generate_email),$(generate_credit_card),$card_type,${expiry_month}/${expiry_year},$(generate_iban),\$${balance},\$${amount},$transaction_date,$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records Financial records in $filename"
    FINANCIAL_COUNT=$num_records
}

# Function to generate PCI data
generate_pci_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/pci_data.csv"
    
    print_status "Generating PCI data ($num_records records)..."
    
    create_csv_file "$filename" "ID,Cardholder_Name,Credit_Card,Card_Type,Expiry_Date,CVV,Transaction_Amount,Merchant_ID,Transaction_Date,Created_Date"
    
    for ((i=1; i<=num_records; i++)); do
        local card_type=${CREDIT_CARD_TYPES[$RANDOM % ${#CREDIT_CARD_TYPES[@]}]}
        local amount=$((RANDOM % 5000 + 10))
        local merchant_id="MERCH_$((RANDOM % 9999 + 1000))"
        local expiry_month=$(printf "%02d" $((RANDOM % 12 + 1)))
        local expiry_year=$((RANDOM % 5 + 2025))
        local cvv=$(printf "%03d" $((RANDOM % 1000)))
        local transaction_date=$(date -v-"$((RANDOM % 30))d" +%Y-%m-%d)
        
        echo "$i,$(generate_first_name) $(generate_last_name),$(generate_credit_card),$card_type,${expiry_month}/${expiry_year},${cvv},\$${amount},${merchant_id},$transaction_date,$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records PCI records in $filename"
    PCI_COUNT=$num_records
}

# Function to generate PII data
generate_pii_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/pii_data.csv"
    
    print_status "Generating PII data ($num_records records)..."
    
    create_csv_file "$filename" "ID,First_Name,Last_Name,Email,Phone,Address,SSN,Date_Of_Birth,Driver_License,Passport_Number,Created_Date"
    
    for ((i=1; i<=num_records; i++)); do
        local area_code=$((RANDOM % 800 + 200))
        local phone_prefix=$((RANDOM % 800 + 200))
        local phone_suffix=$((RANDOM % 9000 + 1000))
        local street_num=$((RANDOM % 9999 + 100))
        local street=${STREETS[$RANDOM % ${#STREETS[@]}]}
        local city=${CITIES[$RANDOM % ${#CITIES[@]}]}
        local state=${STATES[$RANDOM % ${#STATES[@]}]}
        local zip=$((RANDOM % 90000 + 10000))
        local dob_year=$((RANDOM % 50 + 1950))
        local dob_month=$(printf "%02d" $((RANDOM % 12 + 1)))
        local dob_day=$(printf "%02d" $((RANDOM % 28 + 1)))
        local dl_state=${STATES[$RANDOM % ${#STATES[@]}]}
        local dl_number="DL$((RANDOM % 9000000 + 1000000))"
        local passport_number="P$((RANDOM % 900000000 + 100000000))"
        
        echo "$i,$(generate_first_name),$(generate_last_name),$(generate_email),${area_code}-${phone_prefix}-${phone_suffix},${street_num} ${street} St, ${city}, ${state} ${zip},$(generate_ssn),${dob_year}-${dob_month}-${dob_day},${dl_state} ${dl_number},${passport_number},$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records PII records in $filename"
    PII_COUNT=$num_records
}

# Function to generate mixed sensitive data
generate_mixed_data() {
    local num_records=${1:-$DEFAULT_RECORDS}
    local filename="$OUTPUT_DIR/mixed_sensitive_data.csv"
    
    print_status "Generating Mixed sensitive data ($num_records records)..."
    
    create_csv_file "$filename" "ID,First_Name,Last_Name,Email,IP_Address,Credit_Card,IBAN,SSN,Internal_IP,Gender,Employment_Status,Salary,Job_Title,Company,Date_Hired,Created_Date"
    
    for ((i=1; i<=num_records; i++)); do
        local salary=$((RANDOM % 150000 + 50000))
        local employment_status=${EMPLOYMENT_STATUSES[$RANDOM % ${#EMPLOYMENT_STATUSES[@]}]}
        local job_title=${JOB_TITLES[$RANDOM % ${#JOB_TITLES[@]}]}
        local company=${COMPANIES[$RANDOM % ${#COMPANIES[@]}]}
        local hire_year=$((RANDOM % 20 + 2000))
        local hire_month=$(printf "%02d" $((RANDOM % 12 + 1)))
        local hire_day=$(printf "%02d" $((RANDOM % 28 + 1)))
        
        echo "$i,$(generate_first_name),$(generate_last_name),$(generate_email),$(generate_ip_address),$(generate_credit_card),$(generate_iban),$(generate_ssn),$(generate_internal_ip),$(generate_gender),$employment_status,\$$salary,$job_title,$company,${hire_year}-${hire_month}-${hire_day},$(date -v-"$((RANDOM % 365))d" +%Y-%m-%d)" >> "$filename"
    done
    
    print_status "Generated $num_records Mixed sensitive records in $filename"
    MIXED_COUNT=$num_records
}

# Function to display beautiful summary
display_summary() {
    # Calculate sensitive patterns
    local credit_card_total=$((FINANCIAL_COUNT + PCI_COUNT + MIXED_COUNT))
    local iban_total=$((FINANCIAL_COUNT + MIXED_COUNT))
    local ssn_total=$((PII_COUNT + MIXED_COUNT))
    local internal_ip_total=$MIXED_COUNT
    local api_keys_total=$((SECRETS_COUNT / 6))  # Approximate since 6 secret types

    echo -e "\n${CYAN}========== DSPM TEST DATA GENERATION SUMMARY =========="
    echo -e "Generated on: $(date)"

    echo -e "${MAGENTA}DATA PROFILES GENERATED:${NC}"
    printf "%-15s %15d records\n" "PHI" "$PHI_COUNT"
    printf "%-15s %15d records\n" "Secrets" "$SECRETS_COUNT"
    printf "%-15s %15d records\n" "Financial" "$FINANCIAL_COUNT"
    printf "%-15s %15d records\n" "PCI" "$PCI_COUNT"
    printf "%-15s %15d records\n" "PII" "$PII_COUNT"
    printf "%-15s %15d records\n" "Mixed" "$MIXED_COUNT"

    echo -e "\n${MAGENTA}SENSITIVE PATTERNS GENERATED:${NC}"
    printf "%-25s %10d\n" "Credit Card Numbers" "$credit_card_total"
    printf "%-25s %10d\n" "IBAN Numbers" "$iban_total"
    printf "%-25s %10d\n" "SSNs" "$ssn_total"
    printf "%-25s %10d\n" "Internal IPs" "$internal_ip_total"
    printf "%-25s %10d\n" "API Keys" "$api_keys_total"
    printf "%-25s %10d\n" "Medical Records" "$PHI_COUNT"

    echo -e "\n${MAGENTA}OUTPUT LOCATION:${NC}"
    echo "Directory: $(realpath "$OUTPUT_DIR")"

    if [[ "$AWS_UPLOAD" == "true" ]]; then
        echo -e "\n${MAGENTA}AWS S3 UPLOAD:${NC}"
        echo "Uploaded to: s3://$S3_BUCKET"
        if [[ "$MAKE_PUBLIC" == "true" ]]; then
            echo -e "${YELLOW}PUBLIC ACCESS: Enabled${NC}"
        else
            echo -e "${BLUE}Access: Private${NC}"
        fi
    fi
}

# Function to show file summary table
show_file_summary_table() {
    echo -e "\n${CYAN}============= GENERATED FILES SUMMARY ================="
    printf "%-25s %10s %12s\n" "Filename" "Size" "Records"

    for file in "$OUTPUT_DIR"/*; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            filesize=$(du -h "$file" | cut -f1)
            record_count=$(( $(wc -l < "$file") - 1 ))
            printf "%-25s %10s %12d\n" "$filename" "$filesize" "$record_count"
        fi
    done
}

# Function to check AWS credentials and CLI
check_aws_credentials() {
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_warning "AWS CLI is not installed. Skipping AWS upload option."
        return 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials not configured or invalid. Skipping AWS upload option."
        return 1
    fi
    
    return 0
}

# Function to prompt for S3 bucket name
prompt_for_bucket_name() {
    local default_bucket="dspm-test-data-$(date +%Y%m%d-%H%M%S)"
    
    echo -e "${BLUE}AWS S3 Upload Options:${NC}"
    echo "Current AWS Identity: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "Unknown")"
    echo ""
    read -p "Enter S3 bucket name (default: $default_bucket): " bucket_name
    
    if [[ -z "$bucket_name" ]]; then
        bucket_name="$default_bucket"
    fi
    
    # Validate bucket name (basic validation)
    if [[ ! "$bucket_name" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]] || [[ ${#bucket_name} -lt 3 ]] || [[ ${#bucket_name} -gt 63 ]]; then
        print_error "Invalid bucket name. Must be 3-63 characters, lowercase letters, numbers, dots, and hyphens only."
        return 1
    fi
    
    # Ask about public access
    echo ""
    echo -e "${RED}WARNING: This data contains sensitive test patterns!${NC}"
    echo -e "${RED}Making the bucket public will expose this data to the internet!${NC}"
    echo -e "${RED}Only use public access for testing in controlled environments!${NC}"
    echo ""
    read -p "$(echo -e "${YELLOW}Make bucket publicly accessible? (y/N): ${NC}")" public_choice
    
    if [[ "$public_choice" =~ ^[Yy]$ ]]; then
        MAKE_PUBLIC=true
        echo -e "${RED}WARNING: Bucket will be configured for public access!${NC}"
    else
        MAKE_PUBLIC=false
    fi
    
    S3_BUCKET="$bucket_name"
    return 0
}

# Function to create S3 bucket
create_s3_bucket() {
    local bucket_name="$1"
    local make_public="$2"
    
    print_status "Creating S3 bucket: $bucket_name"
    
    # Check if bucket already exists
    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        print_warning "Bucket $bucket_name already exists. Using existing bucket."
        
        # If making public, still apply public access settings
        if [[ "$make_public" == "true" ]]; then
            print_status "Applying public access settings to existing bucket..."
            configure_public_access "$bucket_name"
        fi
        
        return 0
    fi
    
    # Create bucket with appropriate location constraint
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
        # us-east-1 doesn't need location constraint
        if aws s3api create-bucket --bucket "$bucket_name" --region "$AWS_REGION" >/dev/null 2>&1; then
            print_status "Successfully created bucket: $bucket_name in region: $AWS_REGION"
        else
            print_error "Failed to create bucket: $bucket_name"
            return 1
        fi
    else
        # Other regions need location constraint
        if aws s3api create-bucket --bucket "$bucket_name" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null 2>&1; then
            print_status "Successfully created bucket: $bucket_name in region: $AWS_REGION"
        else
            print_error "Failed to create bucket: $bucket_name"
            return 1
        fi
    fi
    
    # Configure access settings based on public flag
    if [[ "$make_public" == "true" ]]; then
        print_status "Configuring bucket for public access..."
        configure_public_access "$bucket_name"
    else
        print_status "Applying security settings to bucket..."
        configure_private_access "$bucket_name"
    fi
    
    # Add bucket tagging
    local public_tag=""
    if [[ "$make_public" == "true" ]]; then
        public_tag=",{Key=PublicAccess,Value=true}"
    fi
    
    aws s3api put-bucket-tagging \
        --bucket "$bucket_name" \
        --tagging "TagSet=[{Key=Purpose,Value=DSPM-Test-Data},{Key=CreatedBy,Value=DSPM-Data-Generator},{Key=Environment,Value=Testing}$public_tag]" \
        >/dev/null 2>&1 || print_warning "Could not apply bucket tags"
    
    return 0
}

# Function to configure public access
configure_public_access() {
    local bucket_name="$1"
    
    print_warning "Configuring bucket for PUBLIC access - data will be visible to the internet!"
    
    # Remove public access block
    aws s3api delete-public-access-block --bucket "$bucket_name" >/dev/null 2>&1 || print_warning "Could not remove public access block"
    
    # Set ownership controls to ObjectWriter (disables ACLs)
    aws s3api put-bucket-ownership-controls \
        --bucket "$bucket_name" \
        --ownership-controls 'Rules=[{ObjectOwnership="ObjectWriter"}]' \
        >/dev/null 2>&1 || print_warning "Could not set ownership controls"
    
    # Create public read policy
    local public_policy=$(cat << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$bucket_name/*"
        }
    ]
}
EOF
)
    
    # Apply public read policy
    if echo "$public_policy" | aws s3api put-bucket-policy --bucket "$bucket_name" --policy file:///dev/stdin >/dev/null 2>&1; then
        print_warning "Bucket configured for public read access"
        print_warning "Files will be accessible at: https://$bucket_name.s3.$AWS_REGION.amazonaws.com/"
    else
        print_error "Failed to apply public read policy"
        return 1
    fi
    
    return 0
}

# Function to configure private access
configure_private_access() {
    local bucket_name="$1"
    
    # Add bucket policy to block public access (security best practice)
    aws s3api put-public-access-block \
        --bucket "$bucket_name" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        >/dev/null 2>&1 || print_warning "Could not apply public access block settings"
    
    print_status "Bucket configured for private access only"
    return 0
}

# Function to upload files to S3
upload_to_s3() {
    local bucket_name="$1"
    local local_dir="$2"
    local make_public="$3"
    
    print_status "Uploading files to S3 bucket: $bucket_name"
    
    # Create a timestamp prefix for organization
    local timestamp=$(date +%Y/%m/%d/%H%M%S)
    local s3_prefix="dspm-test-data/$timestamp"
    
    # Upload all files in the directory (without ACLs)
    if aws s3 cp "$local_dir" "s3://$bucket_name/$s3_prefix/" --recursive --quiet; then
        print_status "Successfully uploaded files to s3://$bucket_name/$s3_prefix/"
        echo ""
        echo -e "${BLUE}S3 Upload Summary:${NC}"
        echo "Bucket: $bucket_name"
        echo "Path: s3://$bucket_name/$s3_prefix/"
        echo "Region: $AWS_REGION"
        
        if [[ "$make_public" == "true" ]]; then
            echo -e "${YELLOW}Public Access: YES - Files are publicly accessible!${NC}"
            echo "Public URLs:"
            for file in "$local_dir"/*; do
                if [[ -f "$file" ]]; then
                    filename=$(basename "$file")
                    echo "  https://$bucket_name.s3.$AWS_REGION.amazonaws.com/$s3_prefix/$filename"
                fi
            done
        else
            echo "Public Access: NO - Files are private"
        fi
        
        echo "Files uploaded:"
        aws s3 ls "s3://$bucket_name/$s3_prefix/" --recursive --human-readable --summarize 2>/dev/null || echo "  (Unable to list files)"
        echo ""
        echo -e "${BLUE}AWS CLI Commands:${NC}"
        echo "List files:     aws s3 ls s3://$bucket_name/$s3_prefix/ --recursive"
        echo "Download files: aws s3 cp s3://$bucket_name/$s3_prefix/ . --recursive"
        echo "Delete files:   aws s3 rm s3://$bucket_name/$s3_prefix/ --recursive"
        echo "Delete bucket:  aws s3 rb s3://$bucket_name --force"
        
        if [[ "$make_public" == "true" ]]; then
            echo ""
            echo -e "${RED}SECURITY WARNING:${NC}"
            echo -e "${RED}    This bucket contains publicly accessible test data!${NC}"
            echo -e "${RED}    Remember to delete the bucket when testing is complete!${NC}"
        fi
        
        return 0
    else
        print_error "Failed to upload files to S3"
        return 1
    fi
}

# Function to handle AWS upload workflow
handle_aws_upload() {
    local local_dir="$1"
    
    # Check AWS credentials
    if ! check_aws_credentials; then
        return 1
    fi
    
    # Prompt user for upload
    echo ""
    read -p "$(echo -e "${BLUE}Upload generated data to AWS S3? (y/N): ${NC}")" upload_choice
    
    if [[ "$upload_choice" =~ ^[Yy]$ ]]; then
        # Get bucket name from user
        if prompt_for_bucket_name; then
            print_status "Preparing to upload to S3 bucket: $S3_BUCKET"
            if [[ "$MAKE_PUBLIC" == "true" ]]; then
                print_warning "PUBLIC ACCESS ENABLED - Bucket will be publicly accessible!"
            fi
            
            # Create bucket
            if create_s3_bucket "$S3_BUCKET" "$MAKE_PUBLIC"; then
                # Upload files
                if upload_to_s3 "$S3_BUCKET" "$local_dir" "$MAKE_PUBLIC"; then
                    AWS_UPLOAD=true
                    print_status "AWS S3 upload completed successfully!"
                else
                    print_error "AWS S3 upload failed"
                    return 1
                fi
            else
                print_error "Failed to create S3 bucket"
                return 1
            fi
        else
            print_error "Invalid bucket name provided"
            return 1
        fi
    else
        print_status "Skipping AWS S3 upload"
        return 0
    fi
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --num-records NUM    Number of records to generate (default: $DEFAULT_RECORDS)"
    echo "  -t, --type TYPE          Generate specific data type only (financial|pci|pii|mixed|phi|secrets)"
    echo "  -o, --output-dir DIR     Output directory (default: $OUTPUT_DIR)"
    echo "  -s, --s3-bucket BUCKET   Specify S3 bucket for upload"
    echo "  --aws-upload             Enable AWS upload"
    echo "  --public                 Make S3 bucket public (use with caution)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       Generate all data types with default settings"
    echo "  $0 -n 500                Generate 500 records for each type"
    echo "  $0 -t pci -n 100         Generate only PCI data with 100 records"
    echo "  $0 -o /tmp/test_data     Use custom output directory"
    echo "  $0 --aws-upload          Generate data and upload to AWS S3"
}

# Main function
main() {
    # Initialize counts
    PHI_COUNT=0
    SECRETS_COUNT=0
    FINANCIAL_COUNT=0
    PCI_COUNT=0
    PII_COUNT=0
    MIXED_COUNT=0
    
    local num_records=$DEFAULT_RECORDS
    local data_type="all"
    local output_dir=$OUTPUT_DIR
    local aws_upload_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--num-records)
                num_records="$2"
                shift 2
                ;;
            -o|--output-dir)
                output_dir="$2"
                shift 2
                ;;
            -t|--type)
                data_type="$2"
                shift 2
                ;;
            -s|--s3-bucket)
                S3_BUCKET="$2"
                aws_upload_flag=true
                shift 2
                ;;
            --aws-upload)
                aws_upload_flag=true
                shift
                ;;
            --public)
                MAKE_PUBLIC=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate num_records
    if ! [[ "$num_records" =~ ^[0-9]+$ ]] || [ "$num_records" -lt 1 ]; then
        print_error "Number of records must be a positive integer"
        exit 1
    fi
    
    # Set output directory
    OUTPUT_DIR="$output_dir"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    echo -e "\n${CYAN}===============================================${NC}"
    echo -e "${CYAN}🚀 Starting DSPM realistic data generation...${NC}"
    echo -e "-----------------------------------------------"
    print_status "Output directory: $OUTPUT_DIR"
    print_status "Records per type: $num_records"
    
    # Generate data based on type
    case $data_type in
        "phi")
            generate_phi_data "$num_records"
            ;;
        "secrets")
            generate_secrets_data "$num_records"
            ;;
        "financial")
            generate_financial_data "$num_records"
            ;;
        "pci")
            generate_pci_data "$num_records"
            ;;
        "pii")
            generate_pii_data "$num_records"
            ;;
        "mixed")
            generate_mixed_data "$num_records"
            ;;
        "all")
            generate_phi_data "$num_records"
            generate_secrets_data "$num_records"
            generate_financial_data "$num_records"
            generate_pci_data "$num_records"
            generate_pii_data "$num_records"
            generate_mixed_data "$num_records"
            ;;
        *)
            print_error "Invalid data type: $data_type"
            exit 1
            ;;
    esac
    
    # Handle AWS upload
    if [[ "$aws_upload_flag" == "true" ]]; then
        if [[ -n "$S3_BUCKET" ]]; then
            # Bucket name was provided via command line
            print_status "Preparing to upload to specified S3 bucket: $S3_BUCKET"
            if [[ "$MAKE_PUBLIC" == "true" ]]; then
                print_warning "PUBLIC ACCESS ENABLED - Bucket will be publicly accessible!"
            fi
            if check_aws_credentials; then
                if create_s3_bucket "$S3_BUCKET" "$MAKE_PUBLIC"; then
                    if upload_to_s3 "$S3_BUCKET" "$OUTPUT_DIR" "$MAKE_PUBLIC"; then
                        AWS_UPLOAD=true
                        print_status "AWS S3 upload completed successfully!"
                    else
                        print_error "AWS S3 upload failed"
                    fi
                else
                    print_error "Failed to create S3 bucket"
                fi
            fi
        else
            # Interactive bucket selection
            handle_aws_upload "$OUTPUT_DIR"
        fi
    else
        # Check if AWS is available and offer upload option
        if check_aws_credentials; then
            handle_aws_upload "$OUTPUT_DIR"
        fi
    fi
    
    # Display beautiful summary and file table
    echo -e "\n${GREEN}🎉 Data generation complete!${NC}"
    display_summary
    show_file_summary_table
    
    # Final warnings
    echo -e "\n${RED}===============================================${NC}"
    echo -e "${RED}  WARNING: This is synthetic test data only!${NC}"
    echo -e "${RED}  Do not use with real sensitive information!${NC}"
    echo -e "${RED}=================================================${NC}"
}

# Run main function with all arguments
main "$@"