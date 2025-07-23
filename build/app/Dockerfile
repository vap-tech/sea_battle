FROM ubuntu:22.04

WORKDIR /seabattle

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    cpanminus libmariadb-dev perl-modules-5.34 make gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY seabattle/cpanfile .

# Установка зависимостей Perl
RUN cpanm --installdeps --notest . \
    && rm -rf /root/.cpanm

COPY seabattle/ .

CMD ["morbo", "script/seabattle"]
