export interface Part {
  id: number;
  order_number: string;
  supplier_order: string;
  part_ordered: string;
  part_delivered: string;
  description: string;
  quantity_requested: number;
  invoice_quantity: number;
  qty_received_irium: number;
  status: string;
  cd_lta: string;
  eta: string;
  date_cf: string;
  invoice_number: string;
  actual_position: string;
  operator_name: string;
  po_customer: string;
  comments: string;
  prim_pso: string;
  order_type: string;
  cat_ticket_id: string;
  ticket_status: string;
  ship_by_date: string;
  customer_name: string;
}

export interface StockDispo {
  id: number;
  part_number: string;
  description: string;
  qté_gdc: number;
  qté_jdc: number;
  qté_cat_network: number;
  qté_succ_10: number;
  qté_succ_20: number;
  qté_succ_11: number;
  qté_succ_12: number;
  qté_succ_13: number;
  qté_succ_14: number;
  qté_succ_19: number;
  qté_succ_21: number;
  qté_succ_22: number;
  qté_succ_24: number;
  qté_succ_30: number;
  qté_succ_40: number;
  qté_succ_50: number;
  qté_succ_60: number;
  qté_succ_70: number;
  qté_succ_80: number;
  qté_succ_90: number;
}

export interface PartEquivalence {
  id: number;
  part_number: string;
  description: string;
  equivalence_part: string;
  description_eq: string;
}

export interface Order {
  id: string;
  constructeur: string;
  date_or: string;
  num_or: string;
  part_number: string;
  qte_commandee: number;
  qte_livree: number;
  created_at?: string;
  updated_at?: string;
}

export interface Message {
  id: string;
  content: string;
  role: 'user' | 'assistant';
  timestamp: string;
}

export interface UserStore {
  user: null | {
    id: string;
    email: string;
    role: 'admin' | 'employee' | 'consultant';
  };
  setUser: (user: UserStore['user']) => void;
  logout: () => void;
}

export interface Project {
  id: string;
  name: string;
  description?: string;
  status: 'active' | 'completed' | 'on_hold';
  start_date?: string;
  end_date?: string;
  created_by?: string;
  created_at?: string;
  updated_at?: string;
}

export interface ProjectMachine {
  id: string;
  project_id: string;
  name: string;
  description?: string;
  start_date?: string;
  end_date?: string;
  created_at?: string;
  updated_at?: string;
}

export interface ProjectMachineOrderNumber {
  id: string;
  machine_id: string;
  order_number: string;
  created_at?: string;
}

export interface ProjectMachinePart {
  id: string;
  machine_id: string;
  part_number: string;
  description?: string;
  quantity_required: number;
  created_at?: string;
  updated_at?: string;
}

export interface ProjectSupplierOrder {
  id: string;
  project_id: string;
  supplier_order: string;
  description?: string;
  created_at?: string;
  updated_at?: string;
}

export interface ProjectBranch {
  id: string;
  project_id: string;
  branch_code: string;
  created_at?: string;
}

export interface ProjectBLNumber {
  id: string;
  project_id: string;
  bl_number: string;
  description?: string;
  created_at?: string;
  updated_at?: string;
}

export interface MachineAnalytics {
  machine_id: string;
  machine_name: string;
  total_parts: number;
  availability_percentage: number;
  usage_percentage: number;
  transit_percentage: number;
  invoiced_percentage: number;
  missing_percentage: number;
  parts_details: {
    part_number: string;
    description: string;
    quantity_required: number;
    quantity_available: number;
    quantity_used: number;
    quantity_in_transit: number;
    quantity_invoiced: number;
    quantity_missing: number;
    latest_eta?: string;
  }[];
}

export interface ProjectAnalytics {
  project_id: string;
  project_name: string;
  total_machines: number;
  overall_availability: number;
  overall_usage: number;
  overall_transit: number;
  overall_invoiced: number;
  overall_missing: number;
  machines: MachineAnalytics[];
}

export interface DealerForwardPlanning {
  id: string;
  part_number: string;
  model?: string;
  forecast_quantity: number;
  business_case_notes?: string;
  uploaded_by: string;
  upload_date: string;
  created_at?: string;
  updated_at?: string;
}

export interface UserModuleAccess {
  id: string;
  user_id: string;
  module_name: ModuleName;
  has_access: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface OTCOrder {
  id: string;
  succursale: string;
  operateur: string;
  date_cde: string;
  num_cde: string;
  po_client: string | null;
  reference: string;
  designation: string;
  qte_cde: number;
  qte_livree: number;
  solde: number;
  date_bl: string | null;
  num_bl: string | null;
  status: string;
  num_client: string | null;
  nom_clients: string | null;
  created_at: string;
  updated_at: string;
}

export interface OTCAnalytics {
  succursale: string;
  total_orders: number;
  delivered_orders: number;
  pending_orders: number;
  in_progress_orders: number;
  cancelled_orders: number;
  total_ordered_quantity: number;
  total_delivered_quantity: number;
  total_balance: number;
  delivery_percentage: number;
  earliest_order_date: string;
  latest_order_date: string;
}

export interface UserProjectAccess {
  id: string;
  user_id: string;
  project_id: string;
  created_at?: string;
}

export interface UserProfile {
  id: string;
  email: string;
  role: 'admin' | 'employee' | 'consultant';
  created_at?: string;
  updated_at?: string;
}

export type ModuleName = 
  | 'global_dashboard'
  | 'eta_tracking'
  | 'stock_availability'
  | 'parts_equivalence'
  | 'orders'
  | 'projects'
  | 'dealer_forward_planning'
  | 'otc';