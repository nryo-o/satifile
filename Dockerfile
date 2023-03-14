FROM node:18


WORKDIR /app/

COPY . .

WORKDIR /app/server

RUN npm i -g spago
RUN npm i -g purescript
RUN npm i -g typescript

RUN npm ci
RUN spago install

RUN tsc
RUN spago build
RUN npm run build

# Run
CMD ["node", "index.js"]
