#!/usr/bin/env python3
"""
Firestore graduation_year 변환: 년도 → 회차
2025 → 25, 2001 → 1, 1995 → 95
"""

import firebase_admin
from firebase_admin import credentials, firestore

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 70)
print("🔄 graduation_year 변환: 년도 → 회차")
print("=" * 70)

# 모든 동문 데이터 가져오기
print("\n📂 데이터 로드 중...")
docs = db.collection('alumni').stream()

updated_count = 0
batch = db.batch()

for doc in docs:
    data = doc.to_dict()
    old_year = data.get('graduation_year', 0)
    
    # 이미 회차 형식인 경우 (1-100)
    if old_year > 0 and old_year <= 100:
        continue
    
    # 년도를 회차로 변환
    if old_year >= 2000:
        new_year = old_year - 2000
    elif old_year >= 1900:
        new_year = old_year - 1900
    else:
        new_year = 0
    
    # 유효한 회차인 경우에만 업데이트
    if new_year > 0 and new_year <= 100:
        batch.update(doc.reference, {'graduation_year': new_year})
        updated_count += 1
        
        if updated_count % 100 == 0:
            print(f"  처리 중... {updated_count}개")
        
        # 500개마다 배치 커밋
        if updated_count % 500 == 0:
            batch.commit()
            batch = db.batch()

# 마지막 배치 커밋
if updated_count % 500 != 0:
    batch.commit()

print(f"\n✅ 변환 완료: {updated_count}개 문서 업데이트")
print("\n변환 내용:")
print("  2025 → 25회")
print("  2001 → 1회")
print("  1995 → 95회")
print("=" * 70)
