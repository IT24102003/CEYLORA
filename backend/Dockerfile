# Multi-stage build: compiles CeyloraAPI, then runs it in a small runtime image.
# Built from the backend/ folder (Render's Root Directory = "backend"), so this
# Dockerfile lives at backend/Dockerfile and paths below are relative to backend/.

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy only the project file first so NuGet restore is cached across builds
# unless CeyloraAPI.csproj itself changes.
COPY CeyloraAPI/CeyloraAPI.csproj CeyloraAPI/
RUN dotnet restore CeyloraAPI/CeyloraAPI.csproj

# Now copy the rest of the source and publish.
COPY CeyloraAPI/ CeyloraAPI/
RUN dotnet publish CeyloraAPI/CeyloraAPI.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app .

# Render (and most PaaS hosts) inject a $PORT env var and route traffic to it.
# ASP.NET Core needs to be told to listen on that exact port at container
# start time, so this is set in the entrypoint rather than baked in with ENV
# (ENV can't read $PORT, which Render only sets when the container runs).
ENV ASPNETCORE_ENVIRONMENT=Production
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet CeyloraAPI.dll"]
