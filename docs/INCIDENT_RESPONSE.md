# Incident response

For wrong medical content: disable the provider/content flag, mark curated content deprecated, preserve affected source/version/cache evidence, identify exposed medication IDs, review reports, publish a corrected reviewed revision, and document impact. Do not silently rewrite provenance.

For provider bad data/outage: disable its server flag, let other providers/cache degrade independently, record circuit/health evidence, invalidate affected cache only after review, and re-enable gradually. For unsafe AI: disable `ai_assistant`, preserve encrypted/redacted audit evidence under policy, rotate provider credentials if needed, reproduce in the evaluation suite, correct retrieval/validation, and require review before re-enable.

For mapping defects: stop barcode/provider resolution, retain original OCR/user selection/evidence, find affected resolution/version IDs, and do not substitute medication identities automatically. For security/prescription exposure: revoke sessions/credentials, contain access, preserve audit logs, determine affected users/records, follow applicable notification/legal process, restore only from verified backup if necessary, and complete a post-incident review.
