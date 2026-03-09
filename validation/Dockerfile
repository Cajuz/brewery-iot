FROM nodered/node-red:latest

WORKDIR /usr/src/node-red

COPY package.json .
RUN npm install --unsafe-perm --no-update-notifier --no-fund --only=production

EXPOSE 1880
