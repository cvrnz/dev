# Build from the repo root so the image can include common/ as well as env-gibbon/
cd "$(dirname "$0")/../.."
docker build -f env-gibbon/container/dev-dockerfile -t dev .
