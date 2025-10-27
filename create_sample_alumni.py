#!/usr/bin/env python3
"""
강릉고등학교 총동문회 샘플 데이터 생성 스크립트
100명의 샘플 동문 데이터를 Firestore에 생성합니다.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import random
from datetime import datetime

# Firebase Admin SDK 초기화
cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

# 샘플 데이터
surnames = ['김', '이', '박', '최', '정', '강', '조', '윤', '장', '임', '한', '오', '서', '신', '권', '황', '안', '송', '류', '홍']
given_names_male = ['민준', '서준', '예준', '도윤', '시우', '주원', '하준', '지호', '준서', '건우', '우진', '현우', '선우', '연우', '유준', '정우', '승현', '승우', '지훈', '민성']
given_names_female = ['서연', '서윤', '지우', '서현', '민서', '하은', '하윤', '윤서', '지유', '채원', '지민', '수아', '소율', '예은', '다은', '예린', '수빈', '지원', '채은', '지안']

companies = [
    '삼성전자', 'LG전자', '현대자동차', 'SK하이닉스', '네이버', '카카오', 
    '포스코', '한화', '롯데', 'GS', 'CJ', '신세계', '두산', '효성', 'LS',
    '강릉시청', '강원도청', '교육청', '병원', '대학교', '법률사무소', 
    '회계법인', '건설회사', '은행', '증권사', '보험사', '제약회사',
    '(주)조유', '스타트업', '자영업', '교사', '의사', '변호사', '회계사'
]

job_titles = [
    '대표이사', '전무', '상무', '이사', '부장', '차장', '과장', '대리', '사원',
    '팀장', '실장', '본부장', '센터장', '연구원', '선임연구원', '수석연구원',
    '교수', '부교수', '조교수', '강사', '의사', '변호사', '회계사', '공무원',
    '프리랜서', '자영업자', '대표', '원장', '소장', '컨설턴트'
]

hobbies_list = [
    '등산', '독서', '운동', '여행', '사진', '음악감상', '영화감상', '요리',
    '낚시', '골프', '테니스', '수영', '자전거', '요가', '명상', '그림그리기',
    '악기연주', '춤', '게임', '프로그래밍', '원예', '봉사활동', '캠핑', '드라이브'
]

def generate_phone():
    """한국 휴대전화 번호 생성"""
    return f"010-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}"

def generate_alumni_data(index):
    """동문 데이터 생성"""
    is_male = random.choice([True, False])
    surname = random.choice(surnames)
    given_name = random.choice(given_names_male if is_male else given_names_female)
    full_name = f"{surname}{given_name}"
    
    graduation_year = random.randint(1970, 2020)
    birth_year = graduation_year - 18
    
    phone = generate_phone()
    
    # 이메일 생성
    email_domains = ['gmail.com', 'naver.com', 'daum.net', 'kakao.com', 'hanmail.net']
    email = f"{given_name.lower()}.{surname.lower()}{random.randint(1, 99)}@{random.choice(email_domains)}"
    
    # 직업 정보
    company = random.choice(companies)
    job_title = random.choice(job_titles)
    
    # 주소
    gangneung_districts = ['교동', '포남동', '홍제동', '강남동', '옥천동', '성산동', '저동', '임당동']
    address = f"강원도 강릉시 {random.choice(gangneung_districts)} {random.randint(1, 500)}"
    
    # 취미 (1-3개)
    hobbies = ', '.join(random.sample(hobbies_list, k=random.randint(1, 3)))
    
    # 한마디
    bio_templates = [
        f"반갑습니다! {graduation_year}학번 {full_name}입니다.",
        f"강릉고 동문 여러분 안녕하세요! {company}에서 근무하고 있습니다.",
        f"{graduation_year}년 졸업한 {full_name}입니다. 연락주세요!",
        f"강릉고의 자랑스러운 동문입니다. 언제든 연락주세요!",
        f"동문 여러분과 소통하고 싶습니다. 편하게 연락주세요.",
    ]
    bio = random.choice(bio_templates)
    
    # 재학 당시 반/번호
    school_class = f"{random.randint(1, 12)}반 {random.randint(1, 40)}번"
    
    return {
        'name': full_name,
        'phone': phone,
        'graduation_year': graduation_year,
        'email': email,
        'company': company,
        'job_title': job_title,
        'address': address,
        'birth_date': f"{birth_year}-{random.randint(1, 12):02d}-{random.randint(1, 28):02d}",
        'school_class': school_class,
        'hobbies': hobbies,
        'bio': bio,
        'profile_photo_url': '',  # 프로필 사진은 나중에 업로드
        'is_verified': True,
        'created_at': firestore.SERVER_TIMESTAMP,
        'updated_at': firestore.SERVER_TIMESTAMP,
    }

def main():
    """메인 함수"""
    print("=" * 60)
    print("🏫 강릉고등학교 총동문회 샘플 데이터 생성")
    print("=" * 60)
    
    # 컬렉션 참조
    alumni_ref = db.collection('alumni')
    
    # 기존 데이터 확인
    existing_count = len(list(alumni_ref.limit(1).stream()))
    
    if existing_count > 0:
        print("\n⚠️  경고: 'alumni' 컬렉션에 이미 데이터가 존재합니다.")
        response = input("기존 데이터를 모두 삭제하고 새로 생성하시겠습니까? (yes/no): ")
        if response.lower() != 'yes':
            print("❌ 작업이 취소되었습니다.")
            return
        
        # 기존 데이터 삭제
        print("\n🗑️  기존 데이터 삭제 중...")
        docs = alumni_ref.stream()
        deleted = 0
        for doc in docs:
            doc.reference.delete()
            deleted += 1
        print(f"✅ {deleted}명의 기존 데이터가 삭제되었습니다.")
    
    # 100명의 샘플 동문 생성
    print("\n📝 100명의 샘플 동문 데이터 생성 중...")
    
    created_count = 0
    for i in range(1, 101):
        alumni_data = generate_alumni_data(i)
        
        # 전화번호를 문서 ID로 사용 (중복 방지)
        doc_id = alumni_data['phone'].replace('-', '')
        
        alumni_ref.document(doc_id).set(alumni_data)
        created_count += 1
        
        if i % 10 == 0:
            print(f"진행중... {i}/100명 생성 완료")
    
    print(f"\n✅ 총 {created_count}명의 동문 데이터가 생성되었습니다!")
    print("\n📊 생성된 데이터 통계:")
    print(f"   - 컬렉션: alumni")
    print(f"   - 문서 수: {created_count}")
    print(f"   - 졸업년도: 1970년 ~ 2020년")
    print("\n🎉 샘플 데이터 생성이 완료되었습니다!")
    print("=" * 60)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
