export interface ProductAliasReviewItem {
  product_alias_id: string;
  company_id: number;
  alias_name: string;
  normalized_alias: string;
  product_id: number;
  sku: string;
  canonical_product_name: string;
  evidence_count: number;
  alias_total_evidence_count: number;
  evidence_percent: number;
  candidate_product_count: number;
  proposal_assessment: 'UNAMBIGUOUS_PROPOSAL' | 'CONFLICTING_PROPOSAL';
  affected_historical_lot_count: number;
  is_globally_approvable: boolean;
  status: 'PROPOSED' | 'APPROVED' | 'REJECTED' | 'RETIRED';
  notes: string;
  reviewed_by: string;
  reviewer_email: string;
  reviewed_at: string;
  created_at: string;
  updated_at: string;
}

export interface AliasDecisionResult {
  success: boolean;
  error?: string;
}

export interface User {
  id: string;
  email: string;
  role?: string;
}