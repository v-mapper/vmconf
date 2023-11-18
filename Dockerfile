FROM php:8.2.2-apache

# Remove folders from the html-folder (in case of an update)
WORKDIR /var/www/html/
RUN rm -rf /var/www/html/*

# Copy all files over to the working directory
#COPY . /var/www/html/
COPY ./apk /var/www/html/apk/
COPY ./rom /var/www/html/rom/
COPY ./scripts /var/www/html/scripts/

# Uncomment the lines if you have set up a password
COPY ./.htaccess /var/www/html/
COPY ./config/.htpasswd /var/www/html/config/.htpasswd

# Run the application
RUN docker-php-ext-install pdo
