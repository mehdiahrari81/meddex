import asyncio
import uuid
import sys
import os

# Add services/api to sys path so imports work
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'services', 'api')))

from app.core.config import get_settings
from app.db.session import create_database_engine, create_session_factory
from app.services.governance import GovernanceService
from app.services.drap_parser import DrapParser
from app.services.rxnorm_mapper import RxNormMapper
from app.providers.medication import RxNormProvider
import httpx

settings = get_settings()
engine = create_database_engine(settings)
SessionLocal = create_session_factory(engine)

async def main():
    with open("/tmp/drap_snapshot.csv", "rb") as f:
        content = f.read()
    records = DrapParser.parse_csv(content)
    
    with SessionLocal() as db:
        # We need a user to act as admin. 
        # Actually since actor_id has foreign key to users, we need to bypass or create a fake user.
        from app.models.user import User
        user = db.query(User).first()
        if not user:
            user = User(email="admin-test@example.com", hashed_password="x")
            db.add(user)
            db.commit()
            
        admin_id = user.id
        gov = GovernanceService(db)
        
        # 1. Dry Run
        print("Starting Dry Run...")
        job = gov.dry_run_import(
            dataset_type="drap_products",
            source_name="DRAP Real Sample",
            source_version="2026-08",
            records=records,
            actor_id=admin_id,
            permissions=["sources.manage", "content.edit"],
            request_id="test-req-1"
        )
        print(f"Dry run complete. Job ID: {job.id}, Status: {job.status}")
        print(f"Report: {job.report}")
        
        # 2. Apply
        print("\nApplying Import...")
        applied = gov.apply_import(
            job_id=job.id,
            confirmation=str(job.id),
            actor_id=admin_id,
            permissions=["sources.manage", "content.edit"],
            request_id="test-req-2"
        )
        print(f"Apply complete. Job Status: {applied.status}")
        
        # 3. RxNorm Mapper
        print("\nMapping DRAP to RxNorm...")
        with httpx.Client() as client:
            rx_provider = RxNormProvider(client=client) 
            mapper = RxNormMapper(db, rx_provider)
            mapped = mapper.map_drap_to_rxnorm(limit=5)
            print(f"Mapped {mapped} DRAP records to RxNorm.")

if __name__ == "__main__":
    asyncio.run(main())
