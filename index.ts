import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
Deno.serve(async (req) => {
  if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
  try {
    const url=Deno.env.get('SUPABASE_URL')!, anon=Deno.env.get('SUPABASE_ANON_KEY')!, service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const auth=req.headers.get('Authorization')||'';
    const caller=createClient(url,anon,{global:{headers:{Authorization:auth}}});
    const {data:{user},error:userError}=await caller.auth.getUser();
    if(userError||!user) return Response.json({error:'No autenticado'},{status:401,headers:cors});
    const admin=createClient(url,service);
    const {data:profile}=await admin.from('profiles').select('role').eq('id',user.id).maybeSingle();
    if(profile?.role!=='admin') return Response.json({error:'Solo administración puede invitar usuarios'},{status:403,headers:cors});
    const body=await req.json();
    const email=String(body.email||'').trim().toLowerCase(), full_name=String(body.full_name||'').trim(), role=String(body.role||'dancer');
    if(!email||!full_name||!['admin','coach','dancer'].includes(role)) return Response.json({error:'Datos inválidos'},{status:400,headers:cors});
    const {data,error}=await admin.auth.admin.inviteUserByEmail(email,{data:{full_name,role}});
    if(error) throw error;
    const {error:profileError}=await admin.from('profiles').upsert({id:data.user.id,full_name,role,active:true});
    if(profileError) throw profileError;
    return Response.json({ok:true},{headers:cors});
  } catch(e) { return Response.json({error:e instanceof Error?e.message:'Error interno'},{status:500,headers:cors}); }
});
