class Config:
    JSON_AS_ASCII = False
    JSON_SORT_KEYS = False
    DEBUG = True
    POSTGRES_USER = 'postgres'
    POSTGRES_PASSWORD = ''
    POSTGRES_DB = 'avito_social_network'
    DATABASE_URI = f"postgresql+psycopg2://{POSTGRES_USER}:{POSTGRES_PASSWORD}@localhost:5432/{POSTGRES_DB}"
