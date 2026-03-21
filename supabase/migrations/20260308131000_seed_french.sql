-- LinguaDaily V1 French starter seed

insert into public.languages (id, code, name, native_name)
values
  ('11111111-1111-1111-1111-111111111111', 'fr', 'French', 'Francais')
on conflict (code) do nothing;

insert into public.words (
  id,
  language_id,
  lemma,
  transliteration,
  pronunciation_ipa,
  part_of_speech,
  cefr_level,
  frequency_rank,
  definition,
  usage_notes
)
values
  ('20000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'bonjour', 'bonjour', '/bɔ̃.ʒuʁ/', 'interjection', 'A1', 20, 'Hello; good morning.', 'Polite and universal greeting used in most situations.'),
  ('20000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'merci', 'merci', '/mɛʁ.si/', 'interjection', 'A1', 25, 'Thank you.', 'Can be intensified as "merci beaucoup".'),
  ('20000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 's''il vous plait', 'sil voo pleh', '/sil vu plɛ/', 'phrase', 'A1', 40, 'Please.', 'Formal or neutral politeness marker.'),
  ('20000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'au revoir', 'oh ruh-vwar', '/o ʁə.vwaʁ/', 'phrase', 'A1', 45, 'Goodbye.', 'Standard way to end a conversation.'),
  ('20000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'pardon', 'par-don', '/paʁ.dɔ̃/', 'interjection', 'A1', 65, 'Sorry; excuse me.', 'Used both to apologize and to get attention politely.'),
  ('20000000-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111111', 'oui', 'wee', '/wi/', 'interjection', 'A1', 18, 'Yes.', 'Basic affirmative response.'),
  ('20000000-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111111', 'non', 'noh(n)', '/nɔ̃/', 'interjection', 'A1', 22, 'No.', 'Basic negative response.'),
  ('20000000-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111111', 'aujourd''hui', 'oh-zhoor-dwee', '/o.ʒuʁ.dɥi/', 'adverb', 'A1', 80, 'Today.', 'Common time expression in conversation.'),
  ('20000000-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111111', 'demain', 'duh-man', '/də.mɛ̃/', 'adverb', 'A1', 85, 'Tomorrow.', 'Used for future plans and schedules.'),
  ('20000000-0000-0000-0000-000000000010', '11111111-1111-1111-1111-111111111111', 'eau', 'oh', '/o/', 'noun', 'A1', 95, 'Water.', 'Very common noun, especially in service contexts.'),
  ('20000000-0000-0000-0000-000000000011', '11111111-1111-1111-1111-111111111111', 'pain', 'pan', '/pɛ̃/', 'noun', 'A1', 130, 'Bread.', 'Food staple, frequent in stores and cafes.'),
  ('20000000-0000-0000-0000-000000000012', '11111111-1111-1111-1111-111111111111', 'gare', 'gar', '/ɡaʁ/', 'noun', 'A1', 175, 'Train station.', 'Useful for travel and commuting.'),
  ('20000000-0000-0000-0000-000000000013', '11111111-1111-1111-1111-111111111111', 'billet', 'bee-yeh', '/bi.jɛ/', 'noun', 'A1', 200, 'Ticket.', 'Can refer to train, bus, or event tickets.'),
  ('20000000-0000-0000-0000-000000000014', '11111111-1111-1111-1111-111111111111', 'travail', 'tra-vai', '/tʁa.vaj/', 'noun', 'A1', 90, 'Work; job.', 'Used for workplace and activity contexts.'),
  ('20000000-0000-0000-0000-000000000015', '11111111-1111-1111-1111-111111111111', 'ami', 'ah-mee', '/a.mi/', 'noun', 'A1', 110, 'Friend (male or mixed).', 'Feminine form is "amie".'),
  ('20000000-0000-0000-0000-000000000016', '11111111-1111-1111-1111-111111111111', 'famille', 'fa-mee-yuh', '/fa.mij/', 'noun', 'A1', 100, 'Family.', 'Core relationship noun in everyday talk.'),
  ('20000000-0000-0000-0000-000000000017', '11111111-1111-1111-1111-111111111111', 'apprendre', 'ah-prondr', '/a.pʁɑ̃dʁ/', 'verb', 'A2', 210, 'To learn.', 'Key verb for education and self-improvement contexts.'),
  ('20000000-0000-0000-0000-000000000018', '11111111-1111-1111-1111-111111111111', 'parler', 'par-lay', '/paʁ.le/', 'verb', 'A1', 70, 'To speak.', 'Can be followed by a language: "parler francais".'),
  ('20000000-0000-0000-0000-000000000019', '11111111-1111-1111-1111-111111111111', 'comprendre', 'kom-prondr', '/kɔ̃.pʁɑ̃dʁ/', 'verb', 'A2', 150, 'To understand.', 'High-value verb for comprehension checks.'),
  ('20000000-0000-0000-0000-000000000020', '11111111-1111-1111-1111-111111111111', 'bienvenue', 'bee-ehn-veh-new', '/bjɛ̃.və.ny/', 'interjection', 'A1', 260, 'Welcome.', 'Used to greet someone into a place or group.')
on conflict (language_id, lemma) do nothing;

insert into public.word_audio (word_id, accent, speed, audio_url, duration_ms)
select
  w.id,
  'parisian',
  s.speed,
  'https://cdn.linguadaily.app/audio/fr/' || replace(w.lemma, ' ', '_') || '_' || s.speed || '.mp3',
  case when s.speed = 'native' then 1400 else 2400 end
from public.words w
cross join (values ('native'), ('slow')) as s(speed)
where w.language_id = '11111111-1111-1111-1111-111111111111'
on conflict (word_id, accent, speed) do nothing;

insert into public.example_sentences (word_id, sentence, translation, order_index)
values
  ('20000000-0000-0000-0000-000000000001', 'Bonjour, comment allez-vous ?', 'Hello, how are you?', 1),
  ('20000000-0000-0000-0000-000000000001', 'Elle a dit bonjour en entrant.', 'She said hello when she came in.', 2),

  ('20000000-0000-0000-0000-000000000002', 'Merci pour votre aide.', 'Thank you for your help.', 1),
  ('20000000-0000-0000-0000-000000000002', 'Un grand merci a toute l equipe.', 'A big thank you to the whole team.', 2),

  ('20000000-0000-0000-0000-000000000003', 'Un cafe, s il vous plait.', 'A coffee, please.', 1),
  ('20000000-0000-0000-0000-000000000003', 'Pouvez-vous repeter, s il vous plait ?', 'Can you repeat, please?', 2),

  ('20000000-0000-0000-0000-000000000004', 'Au revoir et bonne journee.', 'Goodbye and have a good day.', 1),
  ('20000000-0000-0000-0000-000000000004', 'Je dois partir, au revoir !', 'I have to go, goodbye!', 2),

  ('20000000-0000-0000-0000-000000000005', 'Pardon, je suis en retard.', 'Sorry, I am late.', 1),
  ('20000000-0000-0000-0000-000000000005', 'Pardon, ou est la sortie ?', 'Excuse me, where is the exit?', 2),

  ('20000000-0000-0000-0000-000000000006', 'Oui, je comprends.', 'Yes, I understand.', 1),
  ('20000000-0000-0000-0000-000000000006', 'Oui, c est possible.', 'Yes, it is possible.', 2),

  ('20000000-0000-0000-0000-000000000007', 'Non, je ne pense pas.', 'No, I do not think so.', 1),
  ('20000000-0000-0000-0000-000000000007', 'Non, merci.', 'No, thank you.', 2),

  ('20000000-0000-0000-0000-000000000008', 'Aujourd hui, il fait beau.', 'Today, the weather is nice.', 1),
  ('20000000-0000-0000-0000-000000000008', 'Je travaille aujourd hui.', 'I am working today.', 2),

  ('20000000-0000-0000-0000-000000000009', 'Demain, nous partons tot.', 'Tomorrow, we leave early.', 1),
  ('20000000-0000-0000-0000-000000000009', 'Je te vois demain.', 'I will see you tomorrow.', 2),

  ('20000000-0000-0000-0000-000000000010', 'Je voudrais de l eau, s il vous plait.', 'I would like some water, please.', 1),
  ('20000000-0000-0000-0000-000000000010', 'L eau est froide.', 'The water is cold.', 2),

  ('20000000-0000-0000-0000-000000000011', 'Je prends du pain.', 'I am taking some bread.', 1),
  ('20000000-0000-0000-0000-000000000011', 'Ce pain est tres bon.', 'This bread is very good.', 2),

  ('20000000-0000-0000-0000-000000000012', 'La gare est a cinq minutes.', 'The station is five minutes away.', 1),
  ('20000000-0000-0000-0000-000000000012', 'Nous attendons a la gare.', 'We are waiting at the station.', 2),

  ('20000000-0000-0000-0000-000000000013', 'Ou puis-je acheter un billet ?', 'Where can I buy a ticket?', 1),
  ('20000000-0000-0000-0000-000000000013', 'Mon billet est dans mon sac.', 'My ticket is in my bag.', 2),

  ('20000000-0000-0000-0000-000000000014', 'Je cherche du travail.', 'I am looking for work.', 1),
  ('20000000-0000-0000-0000-000000000014', 'Le travail commence a neuf heures.', 'Work starts at nine o clock.', 2),

  ('20000000-0000-0000-0000-000000000015', 'C est mon ami.', 'He is my friend.', 1),
  ('20000000-0000-0000-0000-000000000015', 'Mon ami habite a Paris.', 'My friend lives in Paris.', 2),

  ('20000000-0000-0000-0000-000000000016', 'Ma famille est en France.', 'My family is in France.', 1),
  ('20000000-0000-0000-0000-000000000016', 'Je visite ma famille ce week-end.', 'I am visiting my family this weekend.', 2),

  ('20000000-0000-0000-0000-000000000017', 'J aime apprendre le francais.', 'I like learning French.', 1),
  ('20000000-0000-0000-0000-000000000017', 'Nous apprenons chaque jour.', 'We learn every day.', 2),

  ('20000000-0000-0000-0000-000000000018', 'Je parle un peu francais.', 'I speak a little French.', 1),
  ('20000000-0000-0000-0000-000000000018', 'Elle parle tres vite.', 'She speaks very fast.', 2),

  ('20000000-0000-0000-0000-000000000019', 'Je ne comprends pas.', 'I do not understand.', 1),
  ('20000000-0000-0000-0000-000000000019', 'Tu comprends cette phrase ?', 'Do you understand this sentence?', 2),

  ('20000000-0000-0000-0000-000000000020', 'Bienvenue a Paris !', 'Welcome to Paris!', 1),
  ('20000000-0000-0000-0000-000000000020', 'Vous etes les bienvenus.', 'You are welcome (plural).', 2)
on conflict (word_id, order_index) do nothing;
