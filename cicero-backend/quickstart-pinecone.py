from pinecone import Pinecone

pc = Pinecone(
    api_key="pcsk_3TJMZN_4vwps2euyrt6GLH5NW4cBGSAeyqzjvdb7w3Nf77isYqxY8b24tdBfvNMpFJtq62"
)
index = pc.Index("quickstart")
