# Qdrant Vector Database

Qdrant is a vector similarity search engine and vector database designed for AI applications.

## Access Points

- **REST API**: http://localhost:6333
- **gRPC API**: localhost:6334
- **Web Dashboard**: http://localhost:6333/dashboard
- **Remote Access**: https://vectors.${DOMAIN} (via Traefik)

## Quick Start

### 1. Start the Service
```bash
docker-compose up -d qdrant
```

### 2. Initialize Collections
```bash
python3 ./qdrant/init_collections.py
```

## API Usage Examples

### Check Health
```bash
curl http://localhost:6333/health
```

### List Collections
```bash
curl http://localhost:6333/collections
```

### Create a Collection
```bash
curl -X PUT http://localhost:6333/collections/my_collection \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    }
  }'
```

### Insert Vectors
```bash
curl -X PUT http://localhost:6333/collections/my_collection/points \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, ...],
        "payload": {"text": "example text"}
      }
    ]
  }'
```

### Search Vectors
```bash
curl -X POST http://localhost:6333/collections/my_collection/points/search \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 10
  }'
```

## Python Client Example

```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

# Connect to Qdrant
client = QdrantClient("localhost", port=6333)

# Create collection
client.create_collection(
    collection_name="test_collection",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE),
)

# Insert vectors
client.upsert(
    collection_name="test_collection",
    points=[
        PointStruct(
            id=1,
            vector=[0.1] * 768,
            payload={"text": "example"}
        )
    ]
)

# Search
results = client.search(
    collection_name="test_collection",
    query_vector=[0.1] * 768,
    limit=5
)
```

## Pre-configured Collections

The initialization script creates the following collections:

1. **documents** (1536 dims) - For OpenAI embeddings
2. **chat_history** (768 dims) - For conversation storage
3. **code_snippets** (768 dims) - For code search
4. **knowledge_base** (1024 dims) - For custom embeddings

## Configuration

Environment variables:
- `QDRANT_LOG_LEVEL`: Set logging level (default: INFO)
- `QDRANT_MEMORY_LIMIT`: Memory limit for container (default: 4G)

## Monitoring

Check container logs:
```bash
docker logs qdrant-homelab
```

Check container stats:
```bash
docker stats qdrant-homelab
```

## Backup & Restore

### Create Snapshot
```bash
curl -X POST http://localhost:6333/snapshots
```

### List Snapshots
```bash
curl http://localhost:6333/snapshots
```

### Restore from Snapshot
```bash
curl -X PUT http://localhost:6333/collections/my_collection/snapshots/upload \
  -F "snapshot=@/path/to/snapshot.tar"
```

## Integration with Other Services

Qdrant can be integrated with:
- **Open WebUI**: For semantic search in conversations
- **n8n**: For workflow automation with vector search
- **Huginn**: For intelligent agent behaviors
- **Custom applications**: Using REST API or gRPC

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs qdrant-homelab

# Check if port is already in use
sudo lsof -i :6333
```

### Collections not created
```bash
# Re-run initialization
python3 ./qdrant/init_collections.py
```

### Performance issues
- Increase memory limit in docker-compose.yml
- Check disk space: `df -h /mnt/data/qdrant`
- Monitor resource usage: `docker stats qdrant-homelab`

## Resources

- [Official Documentation](https://qdrant.tech/documentation/)
- [API Reference](https://api.qdrant.tech/)
- [Python Client](https://github.com/qdrant/qdrant-client)
- [Examples](https://github.com/qdrant/examples)