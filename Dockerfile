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

RUN git clone --depth 1 -b REL1_45 https://github.com/jaydenkieran/mw-discord.git /var/www/html/extensions/Discord \
    && chown -R www-data:www-data /var/www/html/extensions/Discord

COPY --chown=www-data:www-data \
    extensions/TempUserWords/ \
    /var/www/html/extensions/TempUserWords/

RUN git clone --depth 1 -b REL1_46 https://github.com/wikimedia/mediawiki-extensions-StopForumSpam.git /var/www/html/extensions/StopForumSpam \
    && chown -R www-data:www-data /var/www/html/extensions/StopForumSpam

COPY --chown=www-data:www-data \
    scripts/cron/generateSitemap.sh \
    /usr/local/bin/generateSitemap.sh

COPY --chown=www-data:www-data \
    scripts/cron/updateDenyList.sh \
    /usr/local/bin/updateStopForumSpam.sh

RUN mkdir -p /var/www/html/sitemap \
    && chown -R www-data:www-data /var/www/html/sitemap \
    && chmod +x /usr/local/bin/generateSitemap.sh /usr/local/bin/updateStopForumSpam.sh \
    && printf "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n0 */4 * * * www-data /usr/local/bin/generateSitemap.sh\n" > /etc/cron.d/generateSitemapCRON \
    && chmod 0644 /etc/cron.d/generateSitemapCRON \
    && printf "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n15 3 * * * www-data /usr/local/bin/updateStopForumSpam.sh\n" > /etc/cron.d/updateStopForumSpamCRON \
    && chmod 0644 /etc/cron.d/updateStopForumSpamCRON

# Fail the build immediately if a required extension was not packaged.
RUN test -f /var/www/html/extensions/DavispediaFrontend/extension.json \
    && test -f /var/www/html/extensions/Cowlender/extension.json \
    && test -f /var/www/html/extensions/PictureOfTheDay/extension.json \
    && test -f /var/www/html/extensions/Discord/extension.json \
    && test -f /var/www/html/extensions/TempUserWords/extension.json \
    && test -f /var/www/html/extensions/AbuseFilter/extension.json \
    && test -f /var/www/html/extensions/StopForumSpam/extension.json \
    && test -f /var/www/html/extensions/ConfirmEdit/extension.json \
    && test -f /var/www/html/extensions/ConfirmEdit/QuestyCaptcha/extension.json \
    && test -f /usr/local/bin/generateSitemap.sh \
    && test -f /usr/local/bin/updateStopForumSpam.sh

CMD ["sh", "-c", "cron && exec apache2-foreground"]
