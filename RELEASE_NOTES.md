# Easy Lesson 3.11 (beta 1) 🔒

Una funzione in più per i grandi: i **messaggi privati cifrati**. Non è per tutti: la attiva la moderazione, una persona
alla volta, e solo per chi è già verificato 18+. Serve il server 3.12.0 (migrazione 0019) e la moderazione 2.8.0.

## 🔒 Messaggi cifrati
- Se tu e l'altra persona siete autorizzati, nei privati compare un **lucchetto** in alto. Con il lucchetto chiuso i
  messaggi li potete leggere solo voi due: non il server e nemmeno la moderazione.
- Ogni telefono ha la sua chiave segreta, che non lascia mai il telefono. Il server conosce solo la parte pubblica.
- **Codice di sicurezza**: tocca la barra in cima alla conversazione e confrontate le 12 cifre di persona o a voce.
  Se sono uguali, nessuno si è messo in mezzo.
- Se l'altra persona cambia telefono, la barra diventa rossa e ti chiede di riconfrontare il codice.
- Nei messaggi cifrati si manda solo testo: foto e sticker si mandano togliendo il lucchetto.
- **Segnalare** si può ancora: l'app chiede conferma e manda alla moderazione il testo del messaggio che stai segnalando,
  solo quello.
- I limiti di sempre restano: i messaggi durano 7 giorni, e la moderazione vede chi scrive a chi e quando.
- Su un telefono nuovo i messaggi cifrati vecchi non si possono leggere (la chiave era sull'altro telefono).

## 🛡️ Dietro le quinte
- Le chiavi stanno nella memoria sicura del sistema (Keystore su Android, Credential Manager su Windows, libsecret su
  Linux). Il pacchetto `.deb` ora richiede anche `libsecret-1-0`.
