# Stage 1: Build the application
FROM maven:3.9.5-eclipse-temurin-17 AS build
WORKDIR /app
COPY . .
RUN mvn clean package -DskipTests

# Stage 2: Create the final image
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
# Copy the JAR from the build stage
COPY --from=build /app/target/message-app-0.0.1-SNAPSHOT.jar /app/app.jar
EXPOSE 8080
# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]