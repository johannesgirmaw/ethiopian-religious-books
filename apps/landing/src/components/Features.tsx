const features = [
  {
    icon: '📖',
    title: 'Full Orthodox library',
    body: 'The Holy Bible with all 81 books, plus liturgical and spiritual works — organized by genre and searchable in Amharic and Geʽez.',
  },
  {
    icon: '📥',
    title: 'Read offline, anywhere',
    body: 'Download books for secure offline reading. Your library travels with you — on the bus, in church, or off the grid.',
  },
  {
    icon: '🖍️',
    title: 'Highlights & notes',
    body: 'Mark meaningful passages, write personal reflections, and revisit them any time across all your devices.',
  },
  {
    icon: '🗓️',
    title: 'Reading plans',
    body: 'Follow guided daily plans and gentle reminders to keep a steady rhythm of Scripture and study.',
  },
  {
    icon: '🔎',
    title: 'Fast, tolerant search',
    body: 'Find verses and passages instantly — even with partial spelling — with full-text search built for Ethiopic script.',
  },
  {
    icon: '🔄',
    title: 'Synced everywhere',
    body: 'Your progress, favorites and notes stay in sync between web, phone and desktop through your free account.',
  },
];

export default function Features() {
  return (
    <section id="features" className="py-24">
      <div className="container-px">
        <div className="mx-auto max-w-2xl text-center">
          <span className="eyebrow">Why Felege Metsahft</span>
          <h2 className="mt-5 font-display text-3xl font-semibold text-white sm:text-4xl">
            A reverent reading experience, thoughtfully modern
          </h2>
          <p className="mt-4 text-slate-300">
            Everything you need to read, study and treasure the books of the Church.
          </p>
        </div>

        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div
              key={f.title}
              className="glass group rounded-2xl p-6 transition hover:border-brand-400/40 hover:bg-white/[0.06]"
            >
              <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-500/15 text-2xl">
                {f.icon}
              </div>
              <h3 className="mt-5 text-lg font-semibold text-white">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-slate-400">{f.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
