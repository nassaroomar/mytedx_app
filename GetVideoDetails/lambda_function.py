import json
import os
from pymongo import MongoClient

# Connect to the database
MONGO_URI = os.environ.get('MONGO_URI')
client = MongoClient(MONGO_URI)
db = client['mytedx']
collection = db['talks']

def lambda_handler(event, context):
    try:
        #1. Extract the ID from the link (Query Parameters)        
        query_params = event.get('queryStringParameters') or {}
        video_id = query_params.get('id')
        
        # Make sure that the application actually sent the ID
        if not video_id:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing video 'id' parameter"})
            }
            
        # 2. Search for the video in the database
        # We get all the data except the _id of Mongo
        result = collection.find_one({"id": str(video_id)}, {"_id": 0})
        
        if not result:
            return {
                "statusCode": 404,
                "body": json.dumps({"error": "Video not found"})
            }
            
        # 3. Return all video details
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(result)
        }
        
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

                #TEST