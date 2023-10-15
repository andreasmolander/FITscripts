# Python script to transpose a CSV file
#
# Usage: python transposeCSV.py <input_file> <output_file>

import sys
import csv

def main():
    if len(sys.argv) != 3:
        print("Usage: python transposeCSV.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        reader = csv.reader(f)
        data = list(reader)

    with open(output_file, 'w') as f:
        writer = csv.writer(f)
        writer.writerows(zip(*data))

if __name__ == "__main__":
    main()
