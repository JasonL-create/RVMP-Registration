import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authHeader = req.headers.get('Authorization') || ''
    const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } })
    const admin = createClient(url, service)

    const { data: { user }, error: userErr } = await caller.auth.getUser()
    if (userErr || !user) throw new Error('Please sign in again.')

    const { data: organizer } = await admin.from('organizers').select('user_id').eq('user_id', user.id).maybeSingle()
    if (!organizer) return json({ error: 'Organizer access required.' }, 403)

    const body = await req.json()
    if (body.action === 'list') {
      const { data: rows, error } = await admin.from('organizers').select('user_id,display_name').order('display_name')
      if (error) throw error
      const { data: usersData, error: usersErr } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 })
      if (usersErr) throw usersErr
      const users = new Map(usersData.users.map(u => [u.id, u]))
      return json({ organizers: (rows || []).map(o => {
        const u = users.get(o.user_id)
        return { user_id:o.user_id, display_name:o.display_name, email:u?.email || '', confirmed:!!u?.email_confirmed_at, is_self:o.user_id===user.id }
      }) })
    }

    if (body.action === 'invite') {
      const email = String(body.email || '').trim().toLowerCase()
      const displayName = String(body.display_name || '').trim()
      if (!email || !displayName) return json({ error: 'Name and email are required.' }, 400)
      const redirectTo = req.headers.get('origin') || undefined
      const { data, error } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo, data: { display_name: displayName } })
      if (error) throw error
      if (!data.user) throw new Error('Supabase did not return the invited user.')
      const { error: upsertErr } = await admin.from('organizers').upsert({ user_id:data.user.id, display_name:displayName }, { onConflict:'user_id' })
      if (upsertErr) throw upsertErr
      return json({ ok:true, email })
    }

    if (body.action === 'remove') {
      const target = String(body.user_id || '')
      if (!target) return json({ error:'Organizer ID is required.' }, 400)
      if (target === user.id) return json({ error:'You cannot remove your own organizer access.' }, 400)
      const { count } = await admin.from('organizers').select('*', { count:'exact', head:true })
      if ((count || 0) <= 1) return json({ error:'At least one organizer must remain.' }, 400)
      const { error } = await admin.from('organizers').delete().eq('user_id', target)
      if (error) throw error
      return json({ ok:true })
    }

    return json({ error:'Unknown action.' }, 400)
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400)
  }
})

function json(body: unknown, status=200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type':'application/json' } })
}
