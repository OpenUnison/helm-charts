#!/bin/bash

# Directory containing Helm charts
CHARTS_DIR="."  # Change this to your charts directory
OUTPUT_FILE="/tmp/helm/charts.json"

# Initialize JSON array
echo "[" > "$OUTPUT_FILE"

# Loop through directories in the charts directory
first=true
for chart in "$CHARTS_DIR"/*/; do
    if [[ -f "$chart/Chart.yaml" ]]; then
        # Extract chart name and version, trim whitespace and remove control characters
        CHART_NAME=$(grep -E '^name:' "$chart/Chart.yaml" | awk '{print $2}' | tr -d '[:space:][:cntrl:]')
        CHART_VERSION=$(grep -E '^version:' "$chart/Chart.yaml" | awk '{print $2}' | tr -d '[:space:][:cntrl:]')

        # Check if we successfully got the name and version
        if [[ -n "$CHART_NAME" && -n "$CHART_VERSION" ]]; then
            # Add a comma if it's not the first item
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$OUTPUT_FILE"
            fi

            # Append JSON object
            echo "  {\"name\": \"$CHART_NAME\", \"version\": \"$CHART_VERSION\"}" >> "$OUTPUT_FILE"
        fi
    fi
done

# Close JSON array
echo "]" >> "$OUTPUT_FILE"

echo "JSON file generated: $OUTPUT_FILE"
