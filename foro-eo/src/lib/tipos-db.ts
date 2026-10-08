// Tipos de la base. Crecen a medida que entran los modulos; hoy cubren los
// modulos 5.1 (autenticacion y miembros) y 5.2 (inicio).

export type RolForo = 'member' | 'moderator' | 'moderator_elect' | 'moderator_outgoing'
export type EstadoReunion = 'draft' | 'scheduled' | 'in_progress' | 'closed'

export type Forum = {
  id: string
  name: string
  chapter: string | null
  purpose: string | null
  next_retreat_on: string | null
  created_at: string
  updated_at: string
}

export type Perfil = {
  id: string
  forum_id: string
  email: string
  full_name: string
  avatar_path: string | null
  role: RolForo
  joined_forum_on: string | null
  is_active: boolean
  created_at: string
  updated_at: string
}

export type ValorForo = {
  id: string
  forum_id: string
  label: string
  body: string | null
  position: number
  created_at: string
  updated_at: string
}

export type Reunion = {
  id: string
  forum_id: string
  title: string | null
  scheduled_at: string
  ends_at: string | null
  location: string | null
  status: EstadoReunion
  opened_at: string | null
  closed_at: string | null
  created_by: string | null
  created_at: string
  updated_at: string
}

export type ArgsFijarFecha = {
  p_forum: string
  p_starts_at: string
  p_ends_at?: string | null
  p_location?: string | null
  p_title?: string | null
  p_meeting?: string | null
  p_apply_template?: boolean
  p_supersede_polls?: boolean
}

// La forma sigue la que genera `supabase gen types`, para poder reemplazar este
// archivo por el generado cuando el proyecto este creado.
export type Database = {
  public: {
    Tables: {
      forums: {
        Row: Forum
        Insert: Partial<Forum> & { name: string }
        Update: Partial<Pick<Forum, 'purpose' | 'next_retreat_on' | 'name' | 'chapter'>>
        Relationships: []
      }
      profiles: {
        Row: Perfil
        Insert: Perfil
        // Rol, foro y email no se editan desde la app: los frena un trigger.
        Update: Partial<Pick<Perfil, 'full_name' | 'avatar_path' | 'joined_forum_on'>>
        Relationships: []
      }
      forum_values: {
        Row: ValorForo
        Insert: Pick<ValorForo, 'forum_id' | 'label'> & Partial<ValorForo>
        Update: Partial<Pick<ValorForo, 'label' | 'body' | 'position'>>
        Relationships: []
      }
      meetings: {
        Row: Reunion
        Insert: Pick<Reunion, 'forum_id' | 'scheduled_at'> & Partial<Reunion>
        Update: Partial<Reunion>
        Relationships: []
      }
    }
    Views: { [_ in never]: never }
    Functions: {
      schedule_meeting: { Args: ArgsFijarFecha; Returns: Reunion }
    }
    Enums: { forum_role: RolForo; meeting_status: EstadoReunion }
    CompositeTypes: { [_ in never]: never }
  }
}
