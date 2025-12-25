# マッチング精度向上のための提案
## インタビュー分析に基づく改善策

**作成日**: 2025年12月12日  
**データソース**: インタビュー1（2名のワーカーインタビュー）

---

## 📊 Executive Summary

インタビューから明らかになった主要な知見：
- ワーカーは**リピート志向**が強く、良い施設には繰り返し応募する
- **駐車場の有無**が重要な選択基準（交通費が赤字になるケースあり）
- **業務内容**（特に入浴介助の有無）が応募判断に大きく影響
- **口コミ**と横のつながりが施設選択に重要な役割を果たす
- **1回あたりの報酬額**（9,000円 vs 10,000円）の印象差が大きい

---

## 1. リピート志向を活用した推薦システム

### 現状の課題
- 現在のアルゴリズムは過去の応募履歴を学習しているが、リピート行動の重要性を明示的にモデル化していない
- 「いつもの施設がなければ新しい施設を探す」という行動パターンが反映されていない

### 提案手法

#### 1.1 リピート施設優先スコアの導入

```python
# リピートスコアの計算式
repeat_score = (
    応募回数 * 0.4 +
    直近の応募からの経過時間の逆数 * 0.3 +
    平均評価スコア * 0.3
)
```

**重み付けロジック**:
- **応募回数** (40%): 3回以上応募している施設を「リピート施設」として高評価
- **時間的近接性** (30%): 直近1ヶ月以内に応募した施設を優先
- **評価スコア** (30%): ワーカー側の評価が高い施設を優先

#### 1.2 推薦ロジックの2段階化

```
【第1段階: リピート施設の優先表示】
IF リピート施設の新規求人がある THEN
    リピート施設を上位3件表示
ELSE
    第2段階へ
    
【第2段階: 類似施設の推薦】
- BERT/TF-IDFによる類似度計算
- 以下の新規要素を組み込む
```

---

## 2. 駐車場情報を活用した距離・コスト最適化

### 現状の課題
インタビューより：
> 「駐車場がなかったら結局地下鉄とかで行かなきゃいけない。だいたい交通費って500円なんですよ。往復すると赤字になる。一番近いところで250円なので、車で行けるところがいいな」

### 提案手法

#### 2.1 実質報酬の計算

```python
# 実質報酬の計算式
actual_reward = (
    基本給与 + 
    交通費 - 
    実際の交通費用 - 
    移動時間コスト
)

# 移動時間コスト = 移動時間(分) * 時給換算値
time_cost = travel_time_minutes * (base_hourly_wage / 60)
```

#### 2.2 駐車場有無による重み付け

```python
# 駐車場がある場合のスコアブースト
if has_parking and worker_prefers_car:
    location_score *= 1.3  # 30%のブースト
    
# 交通費が往復実費を下回る場合のペナルティ
if (transportation_allowance < actual_transportation_cost * 2):
    cost_score *= 0.7  # 30%のペナルティ
```

#### 2.3 データベーススキーマの拡張

```sql
-- 求人テーブルに追加すべきカラム
ALTER TABLE jobs ADD COLUMN has_parking BOOLEAN DEFAULT FALSE;
ALTER TABLE jobs ADD COLUMN parking_notes TEXT;  -- 「施設前に駐車可能」など

-- ワーカープロファイルに追加すべきカラム
ALTER TABLE workers ADD COLUMN prefers_parking BOOLEAN DEFAULT FALSE;
ALTER TABLE workers ADD COLUMN has_vehicle BOOLEAN DEFAULT FALSE;
ALTER TABLE workers ADD COLUMN home_location POINT;  -- 位置情報
```

---

## 3. 業務内容の詳細マッチング

### 現状の課題
インタビューより：
> 「お風呂ないとか」「入浴介助があるかどうか」が重要な選択基準

### 提案手法

#### 3.1 業務内容の構造化

```python
# 業務内容の構造化タグ
care_tasks = {
    'bathing': {
        'weight': 0.25,  # 入浴介助の重み
        'preferences': ['none', 'light', 'full']
    },
    'physical_care': {
        'weight': 0.20,
        'preferences': ['low', 'medium', 'high']
    },
    'cognitive_care': {
        'weight': 0.15,  # 認知症対応
        'preferences': ['not_required', 'preferred', 'experienced']
    },
    'shift_type': {
        'weight': 0.20,
        'preferences': ['day', 'evening', 'night', 'flexible']
    },
    'duration': {
        'weight': 0.20,
        'preferences': ['short', 'standard', 'long']  # 短時間/標準/長時間
    }
}
```

#### 3.2 業務内容ベクトルの作成

現在のBERT/TF-IDFアプローチに加えて：

```python
def create_task_vector(job_description):
    """業務内容から特徴ベクトルを作成"""
    vector = {
        'has_bathing': detect_bathing_task(job_description),
        'physical_intensity': estimate_physical_load(job_description),
        'cognitive_care_level': detect_cognitive_care(job_description),
        'duration_hours': extract_duration(job_description)
    }
    return vector

def match_task_preference(worker_history, job_vector):
    """ワーカーの過去の応募傾向とマッチング"""
    # 過去の応募求人の業務内容パターンを抽出
    preferred_tasks = extract_preferred_tasks(worker_history)
    
    # コサイン類似度を計算
    similarity = cosine_similarity(preferred_tasks, job_vector)
    return similarity
```

#### 3.3 業務内容フィルタリング機能

```python
# ワーカーが避けたい業務内容を明示的に除外
def filter_unwanted_tasks(jobs, worker_preferences):
    """ワーカーの避けたい業務を除外"""
    filtered_jobs = []
    
    for job in jobs:
        if worker_preferences.avoid_bathing and job.has_bathing:
            continue
        if worker_preferences.max_physical_load < job.physical_intensity:
            continue
        if worker_preferences.avoid_night_shift and job.is_night_shift:
            continue
            
        filtered_jobs.append(job)
    
    return filtered_jobs
```

---

## 4. 報酬表示の最適化

### 現状の課題
インタビューより：
> 「1回働いて9000円なのと1回働いて1万円ってちょっと違う。見た感じの印象が違う」

### 提案手法

#### 4.1 報酬の表示方法の改善

```python
# 報酬表示の優先順位
def display_reward(job):
    """報酬を魅力的に表示する"""
    
    # 1. トータル報酬を強調（交通費込み）
    total_reward = job.base_salary + job.transportation_fee
    
    # 2. 時給換算も表示
    effective_hourly = total_reward / (job.working_hours - job.break_hours)
    
    # 3. 表示形式
    return {
        'headline': f"¥{total_reward:,}",  # "¥10,000" と表示
        'breakdown': f"時給換算 ¥{effective_hourly:,.0f}",
        'details': f"基本給 ¥{job.base_salary:,} + 交通費 ¥{job.transportation_fee:,}"
    }
```

#### 4.2 報酬額による推薦スコアの調整

```python
def calculate_reward_score(job, worker_history):
    """報酬額スコアの計算"""
    
    # ワーカーの過去の応募求人の平均報酬
    avg_past_reward = calculate_average_reward(worker_history)
    
    # 報酬額のギャップ
    reward_gap = (job.total_reward - avg_past_reward) / avg_past_reward
    
    # スコア計算
    if reward_gap >= 0.1:  # 10%以上高い
        return 1.2  # 20%ブースト
    elif reward_gap >= 0:
        return 1.0
    elif reward_gap >= -0.1:
        return 0.9
    else:
        return 0.7  # 平均より大幅に低い場合はペナルティ
```

---

## 5. 口コミ・評価システムの強化

### 現状の課題
インタビューより：
> 「新しい施設に行くときは業務内容と口コミをメイトします」
> 「モンスケやってる友達が何人かいて、ここヤバかったよとかっていう情報がちょこちょこ入ってくる」

### 提案手法

#### 5.1 口コミの構造化と重み付け

```python
# 口コミスコアの計算
review_score = (
    平均評価点 * 0.3 +
    口コミ件数の対数 * 0.2 +  # 件数が多いほど信頼性が高い
    直近の評価トレンド * 0.3 +
    同じ属性のワーカーからの評価 * 0.2
)
```

#### 5.2 ソーシャルシグナルの活用

```python
def calculate_social_score(job, worker):
    """ソーシャルシグナルのスコア計算"""
    
    score = 0
    
    # 友人・知人が働いた施設
    if has_friend_worked_here(job, worker):
        score += 0.3
    
    # 友人の評価
    friend_reviews = get_friend_reviews(job, worker)
    if friend_reviews:
        avg_friend_rating = calculate_average(friend_reviews)
        score += avg_friend_rating * 0.2
    
    # 同じ属性のワーカーの評価
    similar_worker_reviews = get_similar_worker_reviews(job, worker)
    if similar_worker_reviews:
        avg_similar_rating = calculate_average(similar_worker_reviews)
        score += avg_similar_rating * 0.15
    
    return score
```

#### 5.3 口コミ表示の改善

```
【推薦求人の表示例】

🏥 満開のふるさと
⭐️ 4.8 (23件の口コミ)
👥 あなたと似た経験を持つワーカーから高評価

💰 ¥10,500 (時給換算 ¥1,500)
📍 駐車場あり 🚗
⏰ 8:00-17:00 (休憩1h)
🛁 入浴介助なし

📝 最近の口コミ:
「スタッフが丁寧に教えてくれる」(1週間前)
「利用者さんが穏やか」(2週間前)
```

---

## 6. 時間的要素の考慮

### 現状の課題
- 応募頻度や応募タイミングが考慮されていない
- 副業/本業の違いが反映されていない

### 提案手法

#### 6.1 利用頻度による重み付け

```python
def calculate_frequency_weight(worker):
    """利用頻度による重み調整"""
    
    monthly_applications = get_monthly_application_count(worker)
    
    if monthly_applications <= 5:  # 副業ユーザー
        return {
            'reward_weight': 0.35,  # 報酬を重視
            'location_weight': 0.25,  # 場所も重視
            'familiarity_weight': 0.40  # リピート施設を最重視
        }
    elif monthly_applications >= 15:  # ヘビーユーザー
        return {
            'reward_weight': 0.30,
            'location_weight': 0.20,
            'variety_weight': 0.20,  # 新しい施設の重み
            'familiarity_weight': 0.30
        }
    else:  # 中程度のユーザー
        return {
            'reward_weight': 0.30,
            'location_weight': 0.25,
            'familiarity_weight': 0.45
        }
```

#### 6.2 応募タイミングの分析

```python
def analyze_application_timing(worker_history):
    """ワーカーの応募タイミングパターンを分析"""
    
    patterns = {
        'preferred_days': extract_preferred_days(worker_history),  # 曜日
        'preferred_time': extract_preferred_time(worker_history),  # 時間帯
        'advance_booking': calculate_average_advance_days(worker_history),  # 何日前に応募するか
        'weekend_preference': calculate_weekend_ratio(worker_history)
    }
    
    return patterns

def recommend_by_timing(jobs, worker_patterns):
    """タイミングパターンに基づく推薦"""
    
    for job in jobs:
        timing_score = 0
        
        # 曜日の一致
        if job.day_of_week in worker_patterns['preferred_days']:
            timing_score += 0.3
        
        # 時間帯の一致
        if job.shift_time == worker_patterns['preferred_time']:
            timing_score += 0.25
        
        # 勤務日までの日数が適切か
        days_until_work = (job.work_date - datetime.now()).days
        if abs(days_until_work - worker_patterns['advance_booking']) <= 3:
            timing_score += 0.25
        
        # 週末志向の一致
        is_weekend = job.day_of_week in ['Saturday', 'Sunday']
        if is_weekend and worker_patterns['weekend_preference'] > 0.5:
            timing_score += 0.2
        
        job.timing_score = timing_score
    
    return jobs
```

---

## 7. 統合スコアリングシステムの提案

### 7.1 最終スコアの計算式

```python
def calculate_final_matching_score(job, worker, worker_history):
    """最終的なマッチングスコアの計算"""
    
    # 各要素のスコア計算
    repeat_score = calculate_repeat_score(job, worker_history)
    location_score = calculate_location_score(job, worker)
    task_score = calculate_task_similarity(job, worker_history)
    reward_score = calculate_reward_score(job, worker_history)
    review_score = calculate_review_score(job)
    social_score = calculate_social_score(job, worker)
    timing_score = calculate_timing_score(job, worker_history)
    bert_score = calculate_bert_similarity(job, worker_history)
    
    # 利用頻度による重み調整
    weights = calculate_frequency_weight(worker)
    
    # 最終スコア
    final_score = (
        repeat_score * 0.25 +
        location_score * weights['location_weight'] +
        task_score * 0.15 +
        reward_score * weights['reward_weight'] +
        review_score * 0.10 +
        social_score * 0.05 +
        timing_score * 0.05 +
        bert_score * 0.10
    )
    
    return final_score
```

### 7.2 実装の優先順位

**Phase 1 (即時実装可能):**
1. リピート施設優先ロジック
2. 報酬表示の改善
3. 口コミ表示の強化

**Phase 2 (データ収集後):**
4. 駐車場情報の統合
5. 業務内容の構造化
6. 時間的要素の分析

**Phase 3 (高度な機能):**
7. ソーシャルシグナルの活用
8. 統合スコアリングの最適化
9. A/Bテストによる重み調整

---

## 8. 実装上の考慮事項

### 8.1 データ収集の必要性

```python
# 新たに収集すべきデータ
new_data_requirements = {
    'job_details': [
        'has_parking',
        'parking_capacity',
        'task_breakdown',  # 業務内容の構造化データ
        'physical_intensity_level'
    ],
    'worker_preferences': [
        'has_vehicle',
        'avoid_tasks',  # 避けたい業務のリスト
        'preferred_task_types',
        'home_location'
    ],
    'application_context': [
        'application_timestamp',
        'search_queries',  # 検索キーワード
        'viewed_jobs',  # 閲覧した求人
        'application_source'  # どこから応募したか
    ]
}
```

### 8.2 パフォーマンスの最適化

```python
# キャッシング戦略
cache_strategy = {
    'worker_profile': '24時間キャッシュ',
    'repeat_facilities': '1時間キャッシュ',
    'bert_embeddings': '永続キャッシュ（更新時のみ再計算）',
    'review_scores': '6時間キャッシュ'
}

# 計算の優先順位
calculation_priority = {
    'high': ['repeat_score', 'location_score', 'reward_score'],
    'medium': ['task_score', 'review_score', 'timing_score'],
    'low': ['social_score']  # データが少ない場合はスキップ可能
}
```

### 8.3 プライバシーへの配慮

```python
# 位置情報の処理
def handle_location_privacy(worker_location):
    """位置情報を適切に処理"""
    
    # 正確な住所ではなく、最寄り駅や地区レベルで保存
    approximate_location = get_approximate_location(worker_location)
    
    # 距離計算は行うが、正確な住所は保存しない
    return approximate_location
```

---

## 9. 評価指標の提案

### 9.1 オンライン評価指標

```python
# 推薦システムの効果を測定する指標
evaluation_metrics = {
    'click_through_rate': '推薦求人のクリック率',
    'application_rate': '推薦求人への応募率',
    'repeat_application_rate': 'リピート施設への応募率',
    'user_satisfaction': 'ユーザー満足度（アンケート）',
    'time_to_application': '求人閲覧から応募までの時間'
}

# 目標値
targets = {
    'click_through_rate': '現状の1.5倍',
    'application_rate': '現状の1.3倍',
    'repeat_application_rate': '70%以上を維持',
    'user_satisfaction': '4.5/5.0以上'
}
```

### 9.2 A/Bテストの設計

```python
# A/Bテストグループ
ab_test_groups = {
    'control': '現在のアルゴリズム（BERT/TF-IDFのみ）',
    'test_a': '提案手法（リピート重視）',
    'test_b': '提案手法（報酬最適化重視）',
    'test_c': '提案手法（統合スコア）'
}

# 測定期間
test_duration = '4週間'

# サンプルサイズ
sample_size = '各グループ500名のアクティブユーザー'
```

---

## 10. 次のステップ

### 短期（1-2ヶ月）
1. ✅ インタビューデータの分析完了
2. 🔄 リピート施設優先ロジックの実装
3. 🔄 報酬表示の改善
4. 📊 ベースライン指標の測定

### 中期（3-6ヶ月）
5. 駐車場情報の収集と統合
6. 業務内容の構造化データベース構築
7. A/Bテストの実施
8. ユーザーフィードバックの収集

### 長期（6-12ヶ月）
9. ソーシャル機能の実装
10. 機械学習モデルの継続的改善
11. 追加インタビューによる検証
12. システム全体の最適化

---

## 11. 期待される効果

### 定量的効果
- **応募率の向上**: 30-40%の改善を目標
- **マッチング精度**: Top-5精度で67%→80%以上
- **リピート率**: 現状維持または向上
- **ユーザー満足度**: 4.0→4.5以上

### 定性的効果
- ワーカーの検索時間の短縮
- より適切な求人提示による満足度向上
- 事業者側の採用効率の改善
- プラットフォーム全体の信頼性向上

---

## 12. リスクと対策

### リスク
1. **データ不足**: 駐車場情報などの新規データが不足
   - **対策**: 段階的な導入、既存データでの推論
   
2. **計算コスト増加**: 複雑なスコアリングによるレスポンス遅延
   - **対策**: キャッシング、非同期処理、段階的計算
   
3. **過学習**: 特定のパターンに過度に最適化
   - **対策**: 定期的なモデル評価、多様性の確保

4. **プライバシー懸念**: 位置情報や行動履歴の利用
   - **対策**: 匿名化、透明性の確保、ユーザー同意

---

## まとめ

インタビューから得られた知見に基づき、以下の改善策を提案しました：

1. **リピート志向の活用**: ワーカーの施設選好を明示的にモデル化
2. **駐車場・交通費の最適化**: 実質報酬を考慮した推薦
3. **業務内容の詳細マッチング**: 入浴介助などの具体的なタスクを考慮
4. **報酬表示の改善**: 心理的インパクトを考慮した表示方法
5. **口コミの活用強化**: ソーシャルシグナルの統合

これらの施策により、現在のBERT/TF-IDFベースのアルゴリズムをさらに強化し、実用的なマッチング精度の向上が期待できます。

**次回インタビュー時の追加質問事項**も巻末に記載していますので、さらなる改善にご活用ください。

---

## 付録: 次回インタビュー時の追加質問事項

### ワーカー行動の深掘り
1. 新しい施設を選ぶ際、最初に見る情報は何ですか？（優先順位）
2. 求人を見てから応募するまで、どのくらい時間をかけますか？
3. 複数の求人を比較する際、何件程度を見比べますか？
4. 「この求人は自分に合わない」と判断する基準は何ですか？

### 駐車場・交通に関して
5. 駐車場がない場合、どのくらいの交通費なら許容できますか？
6. 自宅からの距離と報酬額のトレードオフをどう考えますか？
7. 公共交通機関での通勤時間の上限は？

### 業務内容に関して
8. 入浴介助以外に避けたい業務はありますか？
9. 初めての施設で働く際、どんな情報があると安心ですか？
10. 業務内容の記載で「これは分かりにくい」と感じたことは？

### 報酬に関して
11. 時給と1日の総額、どちらを重視しますか？
12. 報酬以外で「お得」と感じる要素はありますか？（まかない、駐車場無料など）

### 口コミ・評価に関して
13. 口コミの星評価と件数、どちらを重視しますか？
14. どんな口コミコメントが応募の決め手になりますか？
15. 友人からの情報と、アプリ内の口コミ、どちらを信頼しますか？
