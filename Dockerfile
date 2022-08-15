FROM ruby:3.1.2-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    libglib2.0-dev \
    ragel \
 && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.3.12 && \
  bundle install -j$(nproc)

WORKDIR /app
