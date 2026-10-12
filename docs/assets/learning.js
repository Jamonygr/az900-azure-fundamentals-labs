(() => {
  'use strict';
  const script = document.currentScript;
  const dataUrl = new URL('questions.json', script.src);
  // Strip the site-relative asset location, preserving a GitHub Pages project prefix.
  const siteBase = new URL('../../', script.src);
  const key = 'az900-learning-v1';
  const read = () => {
    try {
      const value = JSON.parse(localStorage.getItem(key) || '{}');
      return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
    } catch { return {}; }
  };
  const write = value => { try { localStorage.setItem(key, JSON.stringify(value)); return true; } catch { return false; } };
  const el = (tag, text, parent) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (parent) parent.append(node); return node; };
  function progress() {
    document.querySelectorAll('.az900-progress').forEach(host => {
      if (host.dataset.ready) return;
      host.dataset.ready = 'true';
      const label = el('label', undefined, host), checkbox = el('input', undefined, label);
      checkbox.type = 'checkbox'; checkbox.checked = Boolean(read()[host.dataset.labId]?.completed);
      label.append(document.createTextNode(' Mark this lab complete in this browser'));
      checkbox.addEventListener('change', () => {
        const state = read(); state[host.dataset.labId] = {...state[host.dataset.labId], completed:checkbox.checked};
        if (!write(state)) el('p','Browser storage is unavailable; completion will not be saved.',host);
      });
    });
  }
  async function quiz() {
    const host = document.getElementById('az900-quiz');
    if (!host || host.dataset.ready) return;
    host.dataset.ready = 'true';
    let banks;
    try { const response = await fetch(dataUrl); if (!response.ok) throw Error(response.status); banks = await response.json(); }
    catch { host.replaceChildren(); el('p','Could not load questions. Reload the page or use the terminal runner.',host); return; }
    if (!host.isConnected) return;
    host.replaceChildren();
    const controls = el('div', undefined, host); controls.className = 'quiz-controls';
    const label = el('label','Choose a lab ',controls), select = el('select',undefined,label); select.id='quiz-lab';
    banks.forEach(bank => { const option = el('option',`${bank.id} · ${bank.title}`,select); option.value=bank.id; });
    const reset = el('button','Clear saved progress',controls); reset.type='button';
    const status = el('p','',host), area = el('div',undefined,host);
    function render() {
      const bank = banks.find(b => b.id===select.value); area.replaceChildren();
      const previous = read()[bank.id]?.score;
      status.textContent = previous === undefined ? 'No previous score saved for this lab.' : `Previous score: ${previous}/${bank.questions.length}.`;
      const form = el('form',undefined,area);
      bank.questions.forEach((q,index) => {
        const field = el('fieldset',undefined,form); field.className='quiz-question';
        el('legend',`${index+1}. ${q.stem}`,field);
        Object.entries(q.choices).sort(([a],[b]) => a.localeCompare(b)).forEach(([letter,choice]) => {
          const option = el('label',undefined,field), input = el('input',undefined,option);
          input.type='radio'; input.name=q.id; input.value=letter; input.required=true;
          option.append(document.createTextNode(` ${letter}. ${choice}`));
        });
      });
      const submit = el('button','Submit answers',form); submit.type='submit';
      const feedback = el('div',undefined,area); feedback.setAttribute('aria-live','polite');
      form.addEventListener('submit', event => {
        event.preventDefault(); feedback.replaceChildren();
        const answers = new FormData(form); let score=0;
        bank.questions.forEach(q => { if (answers.get(q.id)===q.answer) score++; });
        const summary = el('h2',`Score: ${score}/${bank.questions.length}`,feedback); summary.tabIndex=-1;
        el('p','Review each missed objective, then retry with your own explanation.',feedback);
        bank.questions.forEach(q => {
          const correct = answers.get(q.id)===q.answer;
          const detail = el('details',undefined,feedback); detail.open=!correct;
          el('summary',`${q.id}: ${correct?'Correct':'Review needed'} · Correct answer ${q.answer}`,detail);
          el('p',q.stem,detail);
          Object.entries(q.explanations).sort(([a],[b]) => a.localeCompare(b)).forEach(([letter,why]) => el('p',`${letter}. ${why}`,detail));
          const review = el('a',`Review objective ${q.objective_id}`,detail);
          const target=q.review_url.replace(/README\.md(?=#|$)/,''); review.href=new URL(target,siteBase).href;
          const sources=el('p','Sources: ',detail);
          q.source_urls.forEach((url,i) => { if(i) sources.append(' · '); const link=el('a',`Microsoft reference ${i+1}`,sources); link.href=url; });
        });
        const state=read(); state[bank.id]={...state[bank.id],score};
        if(!write(state)) el('p','Browser storage is unavailable; your score was not saved.',feedback);
        summary.focus();
      });
    }
    select.addEventListener('change',render);
    reset.addEventListener('click',() => {
      if (!write({})) { status.textContent='Browser storage is unavailable; saved progress could not be cleared.'; return; }
      render();
    });
    render();
  }
  function init() { progress(); quiz(); }
  if (typeof document$ !== 'undefined') document$.subscribe(init); else if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
