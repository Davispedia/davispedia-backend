FROM node:20 AS frontend-builder

ARG FRONTEND_REF=main

RUN git clone https://github.com/Davispedia/davispedia-frontend.git /frontend

WORKDIR /frontend

RUN git checkout "${FRONTEND_REF}" \
    && npm ci \
    && npm run build


FROM mediawiki:1.46

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y cron \
    && rm -rf /var/lib/apt/lists/*

COPY --from=frontend-builder --chown=www-data:www-data \
    /frontend/extension.json \
    /var/www/html/extensions/DavispediaFrontend/extension.json

COPY --from=frontend-builder --chown=www-data:www-data \
    /frontend/includes/ \
    /var/www/html/extensions/DavispediaFrontend/includes/

COPY --from=frontend-builder --chown=www-data:www-data \
    /frontend/dist/ \
    /var/www/html/extensions/DavispediaFrontend/dist/

COPY --chown=www-data:www-data \
    extensions/Cowlender/ \
    /var/www/html/extensions/Cowlender/

COPY --chown=www-data:www-data \
    extensions/PictureOfTheDay/ \
    /var/www/html/extensions/PictureOfTheDay/

COPY --chown=www-data:www-data \
    seo-sitemap-cron/generateSitemap.sh \
    /usr/local/bin/generateSitemap.sh

RUN mkdir -p /var/www/html/sitemap \
    && chown -R www-data:www-data /var/www/html/sitemap \
    && chmod +x /usr/local/bin/generateSitemap.sh \
    && printf "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n0 */4 * * * www-data /usr/local/bin/generateSitemap.sh\n" > /etc/cron.d/generateSitemapCRON \
    && chmod 0644 /etc/cron.d/generateSitemapCRON

# Fail the build immediately if a required extension was not packaged.
RUN test -f /var/www/html/extensions/DavispediaFrontend/extension.json \
    && test -f /var/www/html/extensions/Cowlender/extension.json \
    && test -f /var/www/html/extensions/PictureOfTheDay/extension.json \
    && test -f /usr/local/bin/generateSitemap.sh

CMD ["sh", "-c", "cron && exec apache2-foreground"]
