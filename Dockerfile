# 第一阶段：构建前端
FROM node:20-alpine AS frontend-builder

WORKDIR /app

RUN apk add --no-cache git \
    && git clone https://github.com/f4team-cn/f4pan.git /app \
    && rm -rf /app/.git \
    && git clone https://github.com/f4team-cn/f4pan-web.git /temp \
    && cd /temp \
    && npm install && npm run build \
    && cp -r /temp/dist/* /app/public \
    && rm -rf /temp

# 第二阶段：PHP 环境设置
FROM php:8.0-apache-buster 


# 设置工作目录
WORKDIR /var/www/html

# 安装Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
# 复制前端构建文件
COPY --from=frontend-builder /app /var/www/html/
COPY .htaccess /var/www/html/public/.htaccess

# 安装系统依赖、PHP扩展，配置PHP，并设置项目文件
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libonig-dev \
    && docker-php-ext-install -j$(nproc) pdo_mysql mbstring exif pcntl bcmath fileinfo \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "extension=fileinfo" >> $PHP_INI_DIR/php.ini \
    && echo "extension=redis" >> $PHP_INI_DIR/php.ini \
    && composer install \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && sed -i 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite

# 暴露端口80
EXPOSE 80

# 启动Apache
CMD ["apache2-foreground"]
