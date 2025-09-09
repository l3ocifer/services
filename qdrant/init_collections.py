#!/usr/bin/env python3
"""
Initialize Qdrant collections for your homelab services.
This script creates commonly used vector collections for AI/ML applications.
"""

import requests
import json
import time
import sys
from typing import Dict, Any

# Configuration
QDRANT_HOST = "localhost"
QDRANT_PORT = 6333
QDRANT_URL = f"http://{QDRANT_HOST}:{QDRANT_PORT}"

# Define collections to create
COLLECTIONS = {
    "documents": {
        "vectors": {
            "size": 1536,  # OpenAI embeddings dimension
            "distance": "Cosine"
        },
        "payload_schema": {
            "title": {"type": "text"},
            "content": {"type": "text"},
            "source": {"type": "keyword"},
            "timestamp": {"type": "integer"},
            "metadata": {"type": "json"}
        }
    },
    "chat_history": {
        "vectors": {
            "size": 768,  # Sentence transformers dimension
            "distance": "Cosine"
        },
        "payload_schema": {
            "user": {"type": "keyword"},
            "message": {"type": "text"},
            "response": {"type": "text"},
            "timestamp": {"type": "integer"},
            "session_id": {"type": "keyword"}
        }
    },
    "code_snippets": {
        "vectors": {
            "size": 768,
            "distance": "Cosine"
        },
        "payload_schema": {
            "language": {"type": "keyword"},
            "code": {"type": "text"},
            "description": {"type": "text"},
            "tags": {"type": "keyword[]"},
            "project": {"type": "keyword"}
        }
    },
    "knowledge_base": {
        "vectors": {
            "size": 1024,  # Custom model dimension
            "distance": "Cosine"
        },
        "payload_schema": {
            "title": {"type": "text"},
            "content": {"type": "text"},
            "category": {"type": "keyword"},
            "tags": {"type": "keyword[]"},
            "url": {"type": "keyword"},
            "last_updated": {"type": "integer"}
        }
    }
}


def wait_for_qdrant(max_retries: int = 30, delay: int = 2) -> bool:
    """Wait for Qdrant to be available."""
    print(f"Waiting for Qdrant at {QDRANT_URL}...")
    
    for i in range(max_retries):
        try:
            response = requests.get(f"{QDRANT_URL}/")
            if response.status_code == 200:
                print("✓ Qdrant is ready!")
                return True
        except requests.exceptions.RequestException as e:
            if i == 0:
                print(f"  Connection attempt failed: {e}")
        
        if i < max_retries - 1:
            print(f"  Retry {i + 1}/{max_retries}...")
            time.sleep(delay)
    
    print("✗ Qdrant is not available after maximum retries")
    return False


def collection_exists(collection_name: str) -> bool:
    """Check if a collection already exists."""
    try:
        response = requests.get(f"{QDRANT_URL}/collections/{collection_name}")
        return response.status_code == 200
    except:
        return False


def create_collection(name: str, config: Dict[str, Any]) -> bool:
    """Create a single collection."""
    if collection_exists(name):
        print(f"  → Collection '{name}' already exists, skipping...")
        return True
    
    try:
        # Create collection with vector configuration
        payload = {
            "vectors": config["vectors"]
        }
        
        response = requests.put(
            f"{QDRANT_URL}/collections/{name}",
            json=payload
        )
        
        if response.status_code in [200, 201]:
            print(f"  ✓ Created collection '{name}'")
            
            # Create indexes for payload fields if specified
            if "payload_schema" in config:
                for field_name, field_config in config["payload_schema"].items():
                    index_payload = {
                        "field_name": field_name,
                        "field_schema": field_config.get("type", "keyword")
                    }
                    
                    index_response = requests.put(
                        f"{QDRANT_URL}/collections/{name}/index",
                        json=index_payload
                    )
                    
                    if index_response.status_code in [200, 201]:
                        print(f"    → Indexed field '{field_name}'")
            
            return True
        else:
            print(f"  ✗ Failed to create collection '{name}': {response.text}")
            return False
            
    except Exception as e:
        print(f"  ✗ Error creating collection '{name}': {e}")
        return False


def list_collections() -> None:
    """List all existing collections."""
    try:
        response = requests.get(f"{QDRANT_URL}/collections")
        if response.status_code == 200:
            data = response.json()
            collections = data.get("result", {}).get("collections", [])
            
            if collections:
                print("\nExisting collections:")
                for col in collections:
                    print(f"  • {col['name']}")
            else:
                print("\nNo collections found")
    except Exception as e:
        print(f"Error listing collections: {e}")


def main():
    """Main initialization function."""
    print("=" * 60)
    print("Qdrant Collection Initializer")
    print("=" * 60)
    
    # Wait for Qdrant to be available
    if not wait_for_qdrant():
        print("\nExiting: Qdrant is not available")
        sys.exit(1)
    
    # Get Qdrant info
    try:
        response = requests.get(f"{QDRANT_URL}/")
        if response.status_code == 200:
            info = response.json()
            print(f"\nQdrant version: {info.get('version', 'Unknown')}")
    except:
        pass
    
    # Create collections
    print("\nCreating collections...")
    success_count = 0
    
    for name, config in COLLECTIONS.items():
        if create_collection(name, config):
            success_count += 1
    
    print(f"\nCreated {success_count}/{len(COLLECTIONS)} collections successfully")
    
    # List all collections
    list_collections()
    
    print("\n" + "=" * 60)
    print("Initialization complete!")
    print(f"Qdrant UI available at: {QDRANT_URL}/dashboard")
    print("=" * 60)


if __name__ == "__main__":
    main()