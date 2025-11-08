import csv

def convert_by_headers_fixed(input_file, output_file):
    with open(input_file, 'r', encoding='utf-8-sig') as infile, \
         open(output_file, 'w', newline='', encoding='utf-8') as outfile:
        
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames
        # Убираем BOM из названий полей
        clean_fieldnames = [field.replace('\ufeff', '') for field in fieldnames]
        writer = csv.DictWriter(outfile, fieldnames=clean_fieldnames, delimiter='|')
        writer.writeheader()
        
        for row in reader:
            new_row = {}
            
            for field in fieldnames:
                clean_field = field.replace('\ufeff', '')
                value = row[field]
                
                # Обрабатываем только определенные поля
                if clean_field == 'Genres' and value:
                    value = ','.join([g.strip() for g in value.split(',')])
                elif clean_field == 'Country' and value:
                    value = ','.join([c.strip() for c in value.split(',')])
                elif clean_field in ['Description', 'Description Kinopoisk', 'Description Imdb'] and value:
                    value = value.replace('"', '')  # Убираем кавычки только в описаниях
                
                new_row[clean_field] = value
            
            writer.writerow(new_row)

convert_by_headers_fixed('data_films.csv', 'data_films_converted.csv')
convert_by_headers_fixed('imdb_films.csv', 'imdb_films_converted.csv')
