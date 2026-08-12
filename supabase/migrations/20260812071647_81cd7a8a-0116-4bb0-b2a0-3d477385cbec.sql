CREATE POLICY "ticket files own read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'ticket-files' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_staff(auth.uid())));

CREATE POLICY "ticket files own upload" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'ticket-files' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_staff(auth.uid())));

CREATE POLICY "blog images staff write" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'blog-images' AND public.is_staff(auth.uid()));

CREATE POLICY "blog images read" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'blog-images');

CREATE POLICY "blog images staff delete" ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'blog-images' AND public.is_staff(auth.uid()));
