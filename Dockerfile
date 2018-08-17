
FROM anapsix/alpine-java

LABEL maintainer="pwolf@cloudbees.com"

COPY /target/spring-petclinic-1.5.1.jar /app/spring-petclinic.jar

CMD ["java","-jar","/app/spring-petclinic.jar"]