// Tipos de la base. Crecen a medida que entran los modulos; hoy cubren lo que
// toca el modulo 5.1 (autenticacion y miembros).

export type RolForo = 'member' | 'moderator' | 'moderator_elect' | 'moderator_outgoing'

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

// La forma sigue la que genera `supabase gen types`, para poder reemplazar este
// archivo por el generado cuando el proyecto este creado.
export type Database = {
  public: {
    Tables: {
      forums: {
        Row: Forum
        Insert: Partial<Forum> & { name: string }
        Update: Partial<Forum>
        Relationships: []
      }
      profiles: {
        Row: Perfil
        Insert: Perfil
        // Rol, foro y email no se editan desde la app: los frena un trigger.
        Update: Partial<Pick<Perfil, 'full_name' | 'avatar_path' | 'joined_forum_on'>>
        Relationships: []
      }
    }
    Views: { [_ in never]: never }
    Functions: { [_ in never]: never }
    Enums: { forum_role: RolForo }
    CompositeTypes: { [_ in never]: never }
  }
}
