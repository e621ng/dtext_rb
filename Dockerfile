FROM ruby:3.1.3-alpine3.17

RUN apk --no-cache add build-base ragel

COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.4.1 && \
  bundle install -j$(nproc)

WORKDIR /app
