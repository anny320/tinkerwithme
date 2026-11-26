# Circuit Lab compiler — arduino-cli behind a tiny Node server.
FROM node:20-slim

# arduino-cli needs curl + certs to fetch the core.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Keep all Arduino data inside the image.
ENV ARDUINO_DIRECTORIES_DATA=/arduino \
    ARDUINO_DIRECTORIES_DOWNLOADS=/arduino/staging \
    ARDUINO_DIRECTORIES_USER=/arduino/user

# Install arduino-cli, the AVR core (covers Uno / Nano / Mega), and the
# libraries the OLED lesson uses — so those sketches compile out of the box.
RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh \
 && arduino-cli config init \
 && arduino-cli core update-index \
 && arduino-cli core install arduino:avr \
 && arduino-cli lib install "Adafruit SSD1306" "Adafruit GFX Library" \
 && rm -rf /arduino/staging

WORKDIR /app
COPY server.js .

ENV PORT=8080
EXPOSE 8080
CMD ["node", "server.js"]
