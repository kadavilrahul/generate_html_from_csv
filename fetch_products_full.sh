#!/bin/bash

# ------------------ Prerequisites ------------------
for cmd in mysql jq; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

CONFIG_FILE="config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

# ------------------ Load Websites ------------------
mapfile -t WEBSITES < <(jq -r '.websites | keys[]' "$CONFIG_FILE")

if [ ${#WEBSITES[@]} -eq 0 ]; then
    echo "Error: No websites found in config.json"
    exit 1
fi

echo "Available websites:"
for i in "${!WEBSITES[@]}"; do
    echo "$((i+1)). ${WEBSITES[$i]}"
done

read -p "Select website (1-${#WEBSITES[@]}): " choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#WEBSITES[@]})); then
    echo "Invalid choice"
    exit 1
fi

WEBSITE="${WEBSITES[$((choice-1))]}"
echo "Selected: $WEBSITE"

# ------------------ Product Count ------------------
read -p "Number of products to fetch (default: 10): " num_products
num_products=${num_products:-10}
if ! [[ "$num_products" =~ ^[0-9]+$ ]] || ((num_products < 1)); then
    echo "Invalid product count"
    exit 1
fi

# ------------------ Load DB Config ------------------
DB_HOST=$(jq -r ".websites.\"$WEBSITE\".DATABASE_IP" "$CONFIG_FILE")
DB_NAME=$(jq -r ".websites.\"$WEBSITE\".DATABASE_NAME" "$CONFIG_FILE")
DB_USER=$(jq -r ".websites.\"$WEBSITE\".DATABASE_USER" "$CONFIG_FILE")
DB_PASS=$(jq -r ".websites.\"$WEBSITE\".DATABASE_PASSWORD" "$CONFIG_FILE")
TABLE_PREFIX=$(jq -r ".websites.\"$WEBSITE\".DATABASE_TABLE_PREFIX" "$CONFIG_FILE")
DOMAIN=$(jq -r ".websites.\"$WEBSITE\".DOMAIN" "$CONFIG_FILE")

if [[ -z "$DB_HOST" || -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASS" || -z "$TABLE_PREFIX" ]]; then
    echo "Error: Missing DB credentials in config.json"
    exit 1
fi

# ------------------ Output File ------------------
mkdir -p data
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SANITIZED_DOMAIN=$(echo "$DOMAIN" | sed 's/[^a-zA-Z0-9]/_/g')
OUTPUT_FILE="data/products_${SANITIZED_DOMAIN}_${TIMESTAMP}.csv"

echo "Image,Title,Regular Price,Category,Short_description,Description" > "$OUTPUT_FILE"

# ------------------ MySQL Query + CSV Output ------------------
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "
  SELECT
      CONCAT('https://$DOMAIN/wp-content/uploads/', pm_image.meta_value) AS image,
      p.post_title,
      COALESCE(
        (SELECT meta_value FROM ${TABLE_PREFIX}postmeta WHERE post_id = p.ID AND meta_key = '_price'),
        '0'
      ) AS price,
      (
        SELECT GROUP_CONCAT(t.name SEPARATOR ', ')
        FROM ${TABLE_PREFIX}term_relationships tr
        JOIN ${TABLE_PREFIX}term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN ${TABLE_PREFIX}terms t ON tt.term_id = t.term_id
        WHERE tr.object_id = p.ID AND tt.taxonomy = 'product_cat'
      ) AS category,
      p.post_excerpt AS short_description,
      p.post_content AS description
  FROM ${TABLE_PREFIX}posts p
  LEFT JOIN ${TABLE_PREFIX}postmeta pm_thumb ON pm_thumb.post_id = p.ID AND pm_thumb.meta_key = '_thumbnail_id'
  LEFT JOIN ${TABLE_PREFIX}postmeta pm_image ON pm_image.post_id = pm_thumb.meta_value AND pm_image.meta_key = '_wp_attached_file'
  WHERE p.post_type = 'product' AND p.post_status = 'publish'
  LIMIT $num_products
" | awk -F '\t' 'BEGIN {OFS=","}
{
  for (i = 1; i <= NF; i++) {
    gsub(/\r/, "", $i);                     # Remove carriage returns
    gsub(/"/, "\"\"", $i);                 # Escape quotes
    gsub(/<[^>]*>/, "", $i);               # Remove HTML tags
    gsub(/\xE2\x80\x93/, "-", $i);         # En dash to dash
    gsub(/–/, "-", $i);                    # Unicode en dash
    gsub(/•/, "-", $i);                    # Bullet to dash
    gsub(/\\n/, "\r\n", $i);               # Escaped \n to real line breaks
    $i = "\"" $i "\"";                     # Wrap in quotes
  }
  print
}' >> "$OUTPUT_FILE"

# ------------------ Final Result ------------------
if [ $? -eq 0 ]; then
    echo "✅ Success: Exported product data to $OUTPUT_FILE"
else
    echo "❌ Error: MySQL query failed"
    exit 1
fi
