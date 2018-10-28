FROM ruby:2.5.3-alpine

ENV code_dir /code
ENV app_dir /usr/src/app
ENV user app

RUN apk add --update build-base cmake libcurl openssl-dev libgit2 git

ADD . ${app_dir}

RUN adduser -u 9000 -D ${user}
RUN chown -R ${user}:${user} ${app_dir}

USER ${user}
WORKDIR ${app_dir}

RUN gem install rake
RUN bundle install --without debugging development

USER root
RUN apk del build-base cmake

USER ${user}
VOLUME ${code_dir}
WORKDIR ${code_dir}

CMD [ "/usr/src/app/bin/codeclimate-undercover" ]
