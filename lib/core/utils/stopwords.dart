/// Words filtered out of the word cloud and "top words" list.
///
/// English is the baseline. Roman-script Urdu/Hindi is included because
/// code-switched WhatsApp chats are extremely common and, without this list,
/// the word cloud of a bilingual chat is just "hai", "ka", "ho", "nahi".
/// Add more locales here — nothing else in the engine needs to change.
abstract final class Stopwords {
  static const english = <String>{
    'the', 'and', 'for', 'you', 'are', 'but', 'not', 'was', 'this', 'that',
    'with', 'have', 'has', 'had', 'from', 'they', 'them', 'then', 'than',
    'what', 'when', 'where', 'who', 'why', 'how', 'all', 'any', 'can', 'will',
    'just', 'like', 'get', 'got', 'out', 'now', 'one', 'two', 'your', 'yours',
    'its', 'his', 'her', 'him', 'she', 'hers', 'our', 'ours', 'their', 'were',
    'been', 'being', 'does', 'did', 'done', 'doing', 'about', 'into', 'over',
    'some', 'such', 'only', 'other', 'same', 'very', 'too', 'also', 'there',
    'here', 'these', 'those', 'would', 'could', 'should', 'shall', 'may',
    'might', 'must', 'lets', 'let', 'because', 'while', 'after', 'before',
    'again', 'once', 'both', 'each', 'few', 'more', 'most', 'nor', 'own',
    'off', 'under', 'until', 'still', 'even', 'much', 'many', 'want', 'need',
    'know', 'think', 'going', 'went', 'come', 'came', 'say', 'said', 'see',
    'saw', 'make', 'made', 'take', 'took', 'give', 'gave', 'yeah', 'yes',
    'okay', 'sure', 'well', 'good', 'bad', 'right', 'left', 'back', 'thing',
    'things', 'time', 'day', 'today', 'tomorrow', 'yesterday',
  };

  /// Roman-script Urdu / Hindi function words.
  static const romanUrdu = <String>{
    'hai', 'hain', 'tha', 'thi', 'thay', 'the', 'ho', 'hoga', 'hogi', 'hun',
    'hoon', 'kya', 'kyun', 'kyu', 'kaise', 'kaisa', 'kaisi', 'kab', 'kahan',
    'kon', 'kaun', 'nahi', 'nahin', 'nai', 'haan', 'han', 'aur', 'lekin',
    'magar', 'phir', 'fir', 'abhi', 'ab', 'bhi', 'hi', 'to', 'toh', 'tou',
    'mein', 'main', 'mai', 'tum', 'aap', 'wo', 'woh', 'yeh', 'ye', 'iska',
    'uska', 'mera', 'meri', 'tera', 'teri', 'apna', 'apni', 'sab', 'kuch',
    'kuchh', 'bohot', 'bahut', 'bht', 'zyada', 'thora', 'thoda', 'acha',
    'accha', 'theek', 'thik', 'chalo', 'karo', 'kar', 'karna', 'kiya', 'raha',
    'rahi', 'rahe', 'gaya', 'gayi', 'diya', 'liya', 'wala', 'wali', 'jaise',
    'jab', 'agar', 'par', 'pe', 'se', 'ka', 'ki', 'ke', 'ko', 'na', 'ne',
  };

  /// Chat noise that is technically content but useless in a word cloud.
  static const chatFiller = <String>{
    'ok', 'okk', 'okok', 'hmm', 'hmmm', 'hm', 'umm', 'uh', 'ah', 'oh', 'lol',
    'lmao', 'haha', 'hahaha', 'hehe', 'xd', 'idk', 'imo', 'btw', 'omg', 'pls',
    'plz', 'thx', 'ty', 'np', 'nvm', 'wtf', 'brb', 'gtg', 'ttyl', 'yep',
    'yup', 'nope', 'nah', 'ya', 'yaar', 'bro', 'bhai', 'dude',
  };

  static final Set<String> all = {...english, ...romanUrdu, ...chatFiller};

  static bool contains(String word) => all.contains(word);
}
