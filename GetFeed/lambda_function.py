import json
import os
from pymongo import MongoClient

#1. Connect to the database outside the main function (to improve speed on repeated calls)
MONGO_URI = os.environ.get('MONGO_URI')
client = MongoClient(MONGO_URI)
db = client['mytedx']
collection = db['talks']

def lambda_handler(event, context):
    try:
        #2. Select only the required data (Projection) to reduce the amount of data consumed        
        projection = {
            "_id": 0, 
            "id": 1, 
            "title": 1, 
            "image_url": 1, 
            "presenterDisplayName": 1, 
            "duration": 1
        }
        
        #3. Fetch 20 videos        
        cursor = collection.find({}, projection).limit(20)
        results = list(cursor)
        
        #4. Return the result to the application in JSON format        
        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*" # Allow external applications to connect
            },
            "body": json.dumps(results)
        }
        
    except Exception as e:
        # If an error occurs, we send it back for easy tracking
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }

            #TEST