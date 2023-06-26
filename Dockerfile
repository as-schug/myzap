FROM debian:11 AS myzap_2dev
WORKDIR /usr/src/app
RUN apt-get update && apt-get install -y \
    gconf-service \
    libasound2 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libexpat1 \
    libfontconfig1 \
    libgcc1 \
    libgconf-2-4 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    libappindicator1 \
    libnss3 \
    lsb-release \
    xdg-utils \
    wget \
    build-essential \
    apt-transport-https \
    libgbm-dev \
    git \
    jed

RUN apt-get install curl -y \
    && curl -sL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y \
    nodejs

RUN apt-get install -y wget
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update && apt-get -y install google-chrome-stable

#RUN npm i puppeteer-core

FROM myzap_2dev AS myzap_2prod
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
RUN npm i puppeteer
RUN npm i wppconnect-team/wppconnect
RUN npm i wppconnect-team/wa-version
RUN npm i wppconnect-team/wa-js
RUN npm i whatsapp-web.js
RUN npm update -f
COPY . .
COPY .env.prod ./.env
CMD bash ./faz.sh
